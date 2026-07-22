// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(macOS)

import SwiftUI

// MARK: - CorpusBrowserWindowView

/// A value pushed onto the corpus browser's detail-column navigation stack, so deeper
/// levels (a volume's structure, a section's documents) open in the resizable window
/// instead of progressively smaller fixed-size sheets.
///
/// Version history:
///   1.0 — Session 170: replaces the nested volume/section sheets with push navigation
enum CorpusNavValue: Hashable {
    /// A volume's structural overview, keyed by id (the entry is re-looked-up from the manifest).
    case volume(volumeId: String)
    /// A section's document list or structured front-matter view within a volume.
    case section(volumeId: String, section: VolumeSection)
}

/// Standalone macOS window listing all FRUS subseries and their volumes.
///
/// Uses a `NavigationSplitView`: subseries in the sidebar, volumes in the detail column.
/// The detail column hosts a `NavigationStack` (`detailPath`), so selecting a volume — and
/// then a section within it — **pushes** progressively deeper views that each fill the
/// resizable window, rather than opening a stack of progressively smaller fixed-size sheets.
/// The People index and the per-volume connection graph open in their own windows
/// (`frus.people`, `frus.crossReferenceGraph`) — no sheets remain here.
///
/// ## Sidebar controls
/// - **Sort**: toggle between newest-first (descending) and oldest-first (ascending)
/// - **Filter**: hide subseries that have no volumes downloaded to this device
///
/// Version history:
///   1.0 — initial implementation
///   1.1 — sort and filter sidebar controls; volume-structure sheet with in-app
///          download/indexing; `CorpusVolumeDocumentListView` replaced by
///          `CorpusVolumeDetailView` + `CorpusSectionDocumentView`
///   1.2 — Session 87: People toolbar button opens `PersonIndexView` sheet
///   1.3 — Session 170: volume/section drill-down became a resizable detail-column
///          `NavigationStack` (`CorpusNavValue`) instead of nested fixed-size sheets
///   1.4 — Session 2026-07-04 (macOS UI audit gap 12): consumes the
///          `AppState.pendingBrowseVolume` hand-off (Cross-Volume Provenance rows) —
///          selects the volume's subseries and pushes the volume onto the detail path
///   1.5 — Session 2026-07-04 (macOS UI audit B5): the People toolbar button opens the
///          frus.people window instead of a `PersonIndexView` sheet (which stacked the
///          person-detail sheet on top of itself)
struct CorpusBrowserWindowView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    @State private var selectedSubseries: String? = nil
    @State private var searchText: String = ""
    @State private var sortDescending: Bool = true
    @State private var filterDownloaded: Bool = false
    /// Drill-down path for the detail column: volume → section → deeper section. Owned by
    /// the window so it survives detail re-renders and is shared by every pushed level.
    @State private var detailPath: [CorpusNavValue] = []
    /// A volume push deferred until the subseries selection change lands (see
    /// `consumePendingVolume`): the `.onChange(of: selectedSubseries)` observer resets
    /// `detailPath` after every selection change, so pushing the volume synchronously
    /// alongside the selection would be wiped by that reset. The observer applies this
    /// push instead of the reset when it is set.
    @State private var pendingVolumePush: String? = nil

    private var allEntries: [VolumeManifestEntry] {
        appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
    }

    private var subseries: [String] {
        var seen = Set<String>()
        var all = allEntries.compactMap { e in
            seen.insert(e.subseries).inserted ? e.subseries : nil
        }
        if filterDownloaded {
            let dm = appState.downloadManager
            all = all.filter { sub in
                allEntries.filter { $0.subseries == sub }
                    .contains { dm?.isVolumeDownloaded($0.volumeId) ?? false }
            }
        }
        return all.sorted {
            let a = Int(String($0.prefix(4))) ?? 0
            let b = Int(String($1.prefix(4))) ?? 0
            return sortDescending ? a > b : a < b
        }
    }

    private func volumes(for sub: String) -> [VolumeManifestEntry] {
        allEntries.filter { $0.subseries == sub }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSubseries) {
                ForEach(subseries, id: \.self) { sub in
                    subseriesRow(sub).tag(sub)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Corpus Browser")
            .navigationSplitViewColumnWidth(min: 150, ideal: 170)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        // B5: the People index is a window (frus.people), browsable
                        // alongside documents — not a modal over this browser. It inherits
                        // this browser's provenance (transitive bind), so its "Find all
                        // mentions" search lands where the browser's own opens do.
                        appState.bindTool(.people, to: appState.provenance(of: .corpusBrowser))
                        openWindow(id: "frus.people")
                        bringMacWindowToFront(id: "frus.people")
                    } label: {
                        Image(systemName: "person.2")
                    }
                    .help("Browse people mentioned in indexed volumes")
                }
                ToolbarItem(placement: .automatic) {
                    Button { sortDescending.toggle() } label: {
                        Image(systemName: sortDescending ? "arrow.down" : "arrow.up")
                    }
                    .help(sortDescending ? "Sort oldest first" : "Sort newest first")
                }
                ToolbarItem(placement: .automatic) {
                    Button { filterDownloaded.toggle() } label: {
                        Image(systemName: filterDownloaded
                              ? "arrow.down.circle.fill" : "arrow.down.circle")
                    }
                    .help(filterDownloaded ? "Show all subseries" : "Show downloaded only")
                }
            }
        } detail: {
            NavigationStack(path: $detailPath) {
                Group {
                    if let sub = selectedSubseries {
                        volumeList(for: sub)
                    } else {
                        ContentUnavailableView(
                            "Select a Subseries",
                            systemImage: "books.vertical",
                            description: Text("Choose a subseries from the list to browse its volumes.")
                        )
                    }
                }
                .navigationDestination(for: CorpusNavValue.self) { value in
                    switch value {
                    case .volume(let volumeId):
                        if let entry = allEntries.first(where: { $0.volumeId == volumeId }) {
                            CorpusVolumeDetailView(volume: entry, path: $detailPath)
                        }
                    case .section(let volumeId, let section):
                        CorpusSectionDocumentView(volumeId: volumeId, section: section, path: $detailPath)
                    }
                }
            }
        }
        // Switching subseries returns to the volume-list root (avoids a stale pushed
        // volume) — unless the change was made by `consumePendingVolume`, whose
        // deferred volume push is applied here instead of the reset.
        .onChange(of: selectedSubseries) { _, _ in
            if let volumeId = pendingVolumePush {
                detailPath = [.volume(volumeId: volumeId)]
                pendingVolumePush = nil
            } else {
                detailPath = []
            }
        }
        // Consume a volume hand-off (Cross-Volume Provenance rows, UI audit gap 12):
        // `.task` covers a window freshly created by the hand-off (`.onChange` misses
        // a value that was already set), `.onChange` covers one already open —
        // mirroring MacSearchWindowView's pendingSearch pattern.
        .task {
            consumePendingVolume()
            // Warm the lazy volume-subject-profiles decode off the main thread while
            // the user is at the subseries/volume lists (see BrowserView's twin note).
            Task.detached(priority: .utility) { _ = VolumeSubjectProfilesStore.shared }
        }
        .onChange(of: appState.pendingBrowseVolume) { _, volumeId in
            guard volumeId != nil else { return }
            consumePendingVolume()
        }
        .frame(minWidth: 540, minHeight: 440)
    }

    /// Applies (and clears) `AppState.pendingBrowseVolume`: selects the volume's
    /// subseries in the sidebar and pushes the volume onto the detail path. When the
    /// subseries selection has to change, the push is deferred through
    /// `pendingVolumePush` so the selection observer's path reset doesn't wipe it.
    private func consumePendingVolume() {
        // #338 step 4: the field is now a scene-addressed Handoff. This singleton window is the sole
        // macOS target (`.macCorpusBrowser`), so the target-check always matches here; the clear is
        // still deferred until the volume entry is resolved (unchanged retry-if-not-found behaviour).
        guard let handoff = appState.pendingBrowseVolume, handoff.target == .macCorpusBrowser else { return }
        let volumeId = handoff.payload
        guard let entry = allEntries.first(where: { $0.volumeId == volumeId }) else { return }
        appState.pendingBrowseVolume = nil
        if selectedSubseries == entry.subseries {
            detailPath = [.volume(volumeId: volumeId)]
        } else {
            pendingVolumePush = volumeId
            selectedSubseries = entry.subseries
        }
        #if DEBUG
        print("[CorpusBrowserWindowView] pendingBrowseVolume consumed: \(volumeId)")
        #endif
    }

    private func subseriesRow(_ sub: String) -> some View {
        let vols = volumes(for: sub)
        let dlCount = vols.filter {
            appState.downloadManager?.isVolumeDownloaded($0.volumeId) ?? false
        }.count
        return HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(sub).font(.system(size: 13))
                Text(dlCount > 0
                     ? "\(dlCount)/\(vols.count) downloaded"
                     : "\(vols.count) volumes")
                    .font(.system(size: 10))
                    .foregroundStyle(dlCount > 0 ? Color.secondary : Color.secondary.opacity(0.5))
            }
            Spacer()
            Button {
                appState.openWordCloud(.subseries(subseriesId: sub), from: nil)   // #338: macOS singleton window
                appState.bindTool(.wordCloud, to: appState.provenance(of: .corpusBrowser))
                openWindow(id: "frus.wordcloud")            // #334: open directly, not via MainWindowView's observer
                bringMacWindowToFront(id: "frus.wordcloud")
            } label: {
                Image(systemName: WordCloudGlyph.symbol)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help(String(localized: "corpus.subseries.wordCloudButton.help",
                         defaultValue: "Word cloud for this subseries"))
            .accessibilityLabel(
                String(localized: "corpus.subseries.wordCloudButton.a11y",
                       defaultValue: "Word cloud for \(sub)")
            )
        }
        .contextMenu {
            Button {
                appState.openWordCloud(.subseries(subseriesId: sub), from: nil)   // #338: macOS singleton window
                appState.bindTool(.wordCloud, to: appState.provenance(of: .corpusBrowser))
                openWindow(id: "frus.wordcloud")            // #334
                bringMacWindowToFront(id: "frus.wordcloud")
            } label: {
                Label { Text(String(localized: "corpus.subseries.wordCloud", defaultValue: "Word Cloud")) }
                    icon: { Image(systemName: WordCloudGlyph.symbol) }
            }
        }
    }

    @ViewBuilder
    private func volumeList(for subseries: String) -> some View {
        let vols = volumes(for: subseries)
        let filtered: [VolumeManifestEntry] = searchText.isEmpty ? vols : vols.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.volumeId.localizedCaseInsensitiveContains(searchText)
        }
        SubseriesVolumeListView(
            subseries: subseries,
            filteredVolumes: filtered,
            searchText: $searchText,
            path: $detailPath
        )
    }
}

// MARK: - SubseriesVolumeListView

/// Volume list for a selected FRUS subseries with per-volume cross-reference graph access.
///
/// Each volume row has a small graph button that opens the Cross-Reference Graph
/// *window* (`frus.crossReferenceGraph`) in its volume-connections stage, pre-selected
/// to that volume — corpus-wide edges, not restricted to the subseries — so the user
/// can see every volume that cross-references the chosen volume regardless of which
/// subseries it belongs to, while this browser stays open beside it.
///
/// Version history:
///   1.0 — extracted from `CorpusBrowserWindowView`
///   1.1 — Session 75: added subseries-scoped `VolumeConnectionGraphView` toolbar toggle
///   1.2 — Session 75: subseries filter removed; per-volume graph button replaces toolbar
///          toggle; volume detail and graph sheets unified under a single `SheetContent` enum
///   1.3 — Session 2026-07-03: volume titles wrap to their full value (three-line clip removed)
///   1.4 — Session 2026-07-04 (macOS UI audit B6): the graph button routes to the
///          frus.crossReferenceGraph window via the `pendingVolumeGraph` hand-off
///          instead of presenting `VolumeConnectionGraphView` in a local sheet — the
///          graph is browsable content, and the window precedent already existed
private struct SubseriesVolumeListView: View {
    let subseries: String
    let filteredVolumes: [VolumeManifestEntry]

    @Binding var searchText: String
    /// The window's detail-column drill-down path; tapping a volume pushes onto it.
    @Binding var path: [CorpusNavValue]

    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    // MARK: - Body

    var body: some View {
        List {
            ForEach(filteredVolumes) { vol in
                volumeRow(vol)
            }
        }
        .listStyle(.inset)
        .searchable(text: $searchText, prompt: "Search volumes…")
        .navigationTitle(subseries)
    }

    // MARK: - Volume Row

    private func volumeRow(_ vol: VolumeManifestEntry) -> some View {
        HStack(spacing: 8) {
            // Primary navigation is a Button, not a whole-row `.onTapGesture` (which is
            // invisible to VoiceOver and unreachable by keyboard). The two accessory actions
            // stay as separate trailing buttons; `CorpusVolumeDetailView`'s rows already use
            // this Button(.plain) pattern.
            Button {
                path.append(.volume(volumeId: vol.volumeId))
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(vol.title)
                        .font(.system(size: 12))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Text(vol.volumeId)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        if let dm = appState.downloadManager, dm.isVolumeDownloaded(vol.volumeId) {
                            Label("Downloaded", systemImage: "arrow.down.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .labelStyle(.titleAndIcon)
                            if (try? appState.indexingPipeline?.isVolumeIndexed(vol.volumeId)) == true {
                                Label("Indexed", systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.green)
                                    .labelStyle(.titleAndIcon)
                            }
                        } else if appState.downloadQueue.contains(vol.volumeId) {
                            Label("Downloading", systemImage: "arrow.down.circle")
                                .font(.system(size: 10))
                                .foregroundStyle(.blue)
                                .labelStyle(.titleAndIcon)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "corpus.volume.row.a11y",
                                       defaultValue: "Volume \(vol.volumeId), \(vol.title)"))
            // The explicit label above replaces the content-derived one, which would
            // otherwise have carried the status badges — restate them as the value so
            // VoiceOver still reports download/index state.
            .accessibilityValue(volumeStatusA11yValue(vol))
            .accessibilityHint(String(localized: "corpus.volume.row.hint",
                                      defaultValue: "Opens the volume's contents"))
            Button {
                appState.openWordCloud(.volume(volumeId: vol.volumeId), from: nil)   // #338: macOS singleton window
                appState.bindTool(.wordCloud, to: appState.provenance(of: .corpusBrowser))
                openWindow(id: "frus.wordcloud")            // #334: open directly, not via MainWindowView's observer
                bringMacWindowToFront(id: "frus.wordcloud")
            } label: {
                Image(systemName: WordCloudGlyph.symbol)
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .help(String(localized: "corpus.volume.wordCloudButton.help",
                         defaultValue: "Word cloud for this volume"))
            .accessibilityLabel(
                String(localized: "corpus.volume.wordCloudButton.a11y",
                       defaultValue: "Word cloud for \(vol.volumeId)")
            )
            Button {
                // B6: hand the volume to the graph window's volume-connections stage
                // (a window, so this list stays open while exploring the graph). The
                // window consumes and clears pendingVolumeGraph. The graph inherits
                // this browser's provenance (transitive bind).
                appState.pendingVolumeGraph = vol.volumeId
                appState.bindTool(.graph, to: appState.provenance(of: .corpusBrowser))
                openWindow(id: "frus.crossReferenceGraph")
                bringMacWindowToFront(id: "frus.crossReferenceGraph")
            } label: {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .help(String(localized: "corpus.volume.graphButton.help",
                         defaultValue: "Cross-reference graph for this volume"))
            .accessibilityLabel(
                String(localized: "corpus.volume.graphButton.a11y",
                       defaultValue: "Cross-reference graph for \(vol.volumeId)")
            )
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button {
                appState.openWordCloud(.volume(volumeId: vol.volumeId), from: nil)   // #338: macOS singleton window
                appState.bindTool(.wordCloud, to: appState.provenance(of: .corpusBrowser))
                openWindow(id: "frus.wordcloud")            // #334
                bringMacWindowToFront(id: "frus.wordcloud")
            } label: {
                Label { Text(String(localized: "corpus.volume.wordCloud", defaultValue: "Word Cloud")) }
                    icon: { Image(systemName: WordCloudGlyph.symbol) }
            }
        }
    }

    /// The download/index state of a volume as a VoiceOver value string, mirroring the
    /// row's visual status badges (which live inside the navigation Button's label and are
    /// therefore replaced by its explicit `accessibilityLabel`). Empty when the volume is
    /// not downloaded and not downloading.
    private func volumeStatusA11yValue(_ vol: VolumeManifestEntry) -> String {
        if appState.downloadManager?.isVolumeDownloaded(vol.volumeId) == true {
            if (try? appState.indexingPipeline?.isVolumeIndexed(vol.volumeId)) == true {
                return String(localized: "corpus.volume.row.status.downloadedIndexed",
                              defaultValue: "Downloaded and indexed")
            }
            return String(localized: "corpus.volume.row.status.downloaded",
                          defaultValue: "Downloaded")
        }
        if appState.downloadQueue.contains(vol.volumeId) {
            return String(localized: "corpus.volume.row.status.downloading",
                          defaultValue: "Downloading")
        }
        return ""
    }
}

// `BoundedTitleHeader` — the height-bounded full-title header used by the corpus-browser
// detail columns below — now lives in its own file, `App/BoundedTitleHeader.swift`
// (extracted Session 1 / #238 so it is reusable and Dynamic-Type-aware).

// MARK: - BoundedSubjectsBlock

/// The macOS host for `VolumeSubjectsChips`: a "Top subjects" header + the chips,
/// bounded in height so the block can never crowd the phase content out of
/// `CorpusVolumeDetailView`'s **non-scrolling** column (the same geometry class
/// `BoundedTitleHeader` exists for — 101 volumes' profiles span 8–9 category groups
/// and three span 10, up to ~540 pt unbounded, against a 440 pt window minimum).
///
/// Mirrors `BoundedTitleHeader`: the natural content height is measured live; the
/// block hugs short profiles exactly and caps tall ones at a Dynamic-Type-scaled
/// maximum, beyond which it scrolls internally.
///
/// Version history:
///   1.0 — Session 9 review: bounds the Top-subjects block (unbounded, it crushed
///          the structure list / Download button for many-category volumes)
private struct BoundedSubjectsBlock: View {
    /// The volume whose subject profile is shown.
    let volume: VolumeManifestEntry

    /// The tallest the block may grow before it scrolls internally. Scaled with the
    /// user's text-size setting (relative to `.caption`, the chips' text style).
    @ScaledMetric(relativeTo: .caption) private var maxHeight: CGFloat = 180

    /// The block's natural height at the current column width, measured live.
    @State private var naturalHeight: CGFloat = 0

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "corpus.volume.subjects.header",
                            defaultValue: "Top subjects"))
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                VolumeSubjectsChips(volume: volume)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { naturalHeight = $0 }
        }
        // Hug short profiles (height == natural), cap tall ones (scrolls internally).
        // Starts at 0 before the first measurement — briefly collapsed is harmless,
        // a greedy height would reintroduce the overflow this guards against.
        .frame(height: min(naturalHeight, maxHeight))
        .scrollDisabled(naturalHeight <= maxHeight)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - CorpusVolumeDetailView

/// A volume's structural overview (chapters, compilations), pushed into the corpus browser
/// window's resizable detail column.
///
/// ## Phase machine
/// ```
/// notDownloaded ──(Download)──► downloading
/// downloading ──(complete)──► indexing   [app auto-indexes after download]
/// notIndexed ──(Index Now)──► indexing
/// indexing ──(pipeline done)──► loadingStructure ──► ready
/// ready ──(tap section)──► pushes CorpusSectionDocumentView onto the detail path
/// ```
///
/// Download progress is inferred from `AppState.downloadQueue` transitions.
/// Indexing progress is read from `AppState.currentIndexingProgress`.
/// Both are `@Observable` properties so the view re-renders automatically.
///
/// Version history:
///   1.0 — Session 51: initial implementation
///   1.1 — Session 113: `DiscoveredMetadataRow` added to indexing phase view
///   1.2 — Session 115: `.interrupted` phase added; amber warning view with Re-index Now button
///   1.3 — Session 2026-06-09: `frontMatterTypes` + `extractFrontMatter` added; `structureView`
///          now splits sections into "Front Matter" and "Contents" headers, matching `VolumeView`
///   1.4 — Session 2026-07-03: full-title header above the phase content — the window
///          title truncates the long appended clauses older volume titles carry
///   1.5 — Session 2026-07-08: the full-title header is now `BoundedTitleHeader` (height
///          capped, scrolls when longer) — an unbounded `fixedSize` title overflowed the
///          non-scrolling column and blanked the volume's contents for long-titled volumes
///   1.6 — Session 1 / #238 hardening: `indexingView` is wrapped in a `ScrollView` so its
///          discovered-metadata row and context card can't be clipped at the window's
///          minimum height (`BoundedTitleHeader` now lives in `App/BoundedTitleHeader.swift`)
///   1.7 — Session 9: "Top subjects" block (bundled volume-subject profiles) above the
///          phase content, height-bounded via `BoundedSubjectsBlock`; `determinePhase`
///          re-keyed on the volume id (`.task(id:)`) — `consumePendingVolume` replaces
///          the path element in place, and the identity-stable view otherwise kept the
///          previous volume's structure under the new volume's header
private struct CorpusVolumeDetailView: View {
    let volume: VolumeManifestEntry
    /// The window's detail-column path; opening a section pushes onto it.
    @Binding var path: [CorpusNavValue]
    @Environment(AppState.self) private var appState
    /// Mint tail for `AppState.openDocument` — when no document host is live, a
    /// prose-section open lands in a fresh standalone document window.
    @Environment(\.openWindow) private var openWindow

    enum Phase {
        case notDownloaded, downloading, indexing, loadingStructure
        case ready(VolumeStructure)
        case error(String)
    }

    @State private var phase: Phase = .notDownloaded
    @State private var liveProgress: IndexingProgressUpdate? = nil
    @State private var showingSummaryCard = false
    /// Whether the downloaded volume has been indexed, and whether a prior indexing pass was
    /// interrupted. These drive a non-blocking status banner (#214): the structure itself is
    /// now browsable regardless, at parity with iOS, so indexing is offered — not required —
    /// to browse. Search / document text / connections still depend on the index.
    @State private var isVolumeIndexed = false
    @State private var isInterrupted = false
    private let parser = FRUSDocumentParser()

    var body: some View {
        // Pushed into the browser window's resizable detail column (not a sheet), so the
        // structure list, and any section drilled into, inherit the window's size.
        // The full volume title heads the content — the window/navigation title truncates
        // the long appended clauses older volumes carry, so the complete value must be
        // readable (and selectable) in the content area. `BoundedTitleHeader` caps that
        // header's height so a paragraph-length title can't push the phase content
        // (structure list / download prompt) out of the non-scrolling column.
        VStack(alignment: .leading, spacing: 0) {
            BoundedTitleHeader(title: volume.title)
            Divider()
            // Top subjects (Session 9): the volume's most characteristic subjects from the
            // bundled aggregate. Placed above the phase content so it shows regardless of
            // download/index state (the profiles are bundled, not index-derived).
            if VolumeSubjectsChips.hasContent(forVolumeId: volume.volumeId) {
                BoundedSubjectsBlock(volume: volume)
                Divider()
            }
            phaseContent
        }
            .navigationTitle(volume.title)
            // Keyed to the volume id: `consumePendingVolume` REPLACES the detail path's
            // `.volume` element in place (same structural position), so SwiftUI reuses
            // this view's identity and a plain `.task` would never re-run — leaving the
            // previous volume's structure under the new volume's header. Reachable from
            // any same-subseries volume hand-off (cross-volume provenance rows, and the
            // Session 9 subject pivot, whose hops are typically within one subseries).
            .task(id: volume.volumeId) {
                liveProgress = nil
                await determinePhase()
            }
        // Download completion: queue no longer contains volumeId AND file now exists → auto-index begins
        .onChange(of: appState.downloadQueue) { _, queue in
            if case .downloading = phase,
               !queue.contains(volume.volumeId),
               appState.downloadManager?.isVolumeDownloaded(volume.volumeId) == true {
                phase = .indexing
                liveProgress = nil
            }
        }
        // Indexing progress: update display; when complete → show summary card.
        // Also handle external indexing: when a batch operation running outside this
        // sheet indexes our volume, progress transitions through our volumeId and
        // eventually becomes nil. We re-evaluate the phase so the sheet doesn't remain
        // stuck on `.notIndexed` after external indexing completes.
        .onChange(of: appState.currentIndexingProgress) { _, progress in
            guard case .indexing = phase else {
                // External indexing finished. Only react when THIS volume's index/interrupt state
                // actually changed — so an unrelated volume completing doesn't trigger a spurious
                // re-parse + "Loading contents…" flash of this (possibly large) volume. Reload the
                // structure only when we just became indexed (to populate section document lists);
                // a bare interrupt-flag change just refreshes the banner.
                if progress == nil {
                    let nowIndexed: Bool = {
                        guard let pipeline = appState.indexingPipeline else { return false }
                        return (try? pipeline.isVolumeIndexed(volume.volumeId)) == true
                    }()
                    let nowInterrupted = appState.interruptedVolumeIds.contains(volume.volumeId)
                    if nowIndexed != isVolumeIndexed || nowInterrupted != isInterrupted {
                        let becameIndexed = nowIndexed && !isVolumeIndexed
                        isVolumeIndexed = nowIndexed
                        isInterrupted = nowInterrupted
                        if becameIndexed, case .ready = phase {
                            Task { await loadStructure() }
                        }
                    }
                }
                return
            }
            if let progress, progress.volumeId == volume.volumeId {
                liveProgress = progress
            } else if progress == nil {
                // Indexing ended — show the summary card if it was our volume, else load directly.
                if appState.completedIndexingMetadata?.volumeId == volume.volumeId {
                    showingSummaryCard = true
                } else {
                    Task { await loadStructure() }
                }
            }
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch phase {
        case .notDownloaded:    notDownloadedView
        case .downloading:      downloadingView
        case .indexing:
            if showingSummaryCard, let meta = appState.completedIndexingMetadata {
                summaryCardView(meta)
            } else {
                indexingView
            }
        case .loadingStructure:
            ProgressView("Loading contents…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready(let s):     structureView(s)
        case .error(let msg):
            ContentUnavailableView(
                "Error",
                systemImage: "exclamationmark.triangle",
                description: Text(msg)
            )
        }
    }

    // MARK: Phase logic

    private func determinePhase() async {
        if appState.downloadQueue.contains(volume.volumeId) { phase = .downloading; return }
        if let p = appState.currentIndexingProgress, p.volumeId == volume.volumeId {
            phase = .indexing; liveProgress = p; return
        }
        guard let dm = appState.downloadManager, dm.isVolumeDownloaded(volume.volumeId) else {
            phase = .notDownloaded; return
        }
        // iOS parity (#214): a downloaded volume's structure is browsable straight from the
        // downloaded XML, regardless of index state. The old macOS gate routed unindexed or
        // interrupted volumes to a content wall — which bit the large early volumes that are
        // most often left downloaded-but-unindexed (or whose long indexing pass was
        // interrupted). Record index/interrupt state for the non-blocking banner, then load
        // the structure; index-dependent affordances stay gated where they are actually used
        // (per-section document lists, search scoping, connections).
        isInterrupted = appState.interruptedVolumeIds.contains(volume.volumeId)
        if let pipeline = appState.indexingPipeline {
            isVolumeIndexed = (try? pipeline.isVolumeIndexed(volume.volumeId)) == true
        } else {
            isVolumeIndexed = false
        }
        await loadStructure()
    }

    /// Kicks off (or restarts) indexing for this volume from the status banner, then reloads
    /// the structure so section document lists populate. Surfaces failures instead of silently
    /// swallowing them (the "persisted after reindex" report, #214).
    private func indexVolume() {
        guard let pipeline = appState.indexingPipeline else { return }
        phase = .indexing
        liveProgress = nil
        Task {
            do {
                try await pipeline.indexVolume(volume.volumeId)
                isVolumeIndexed = true
                isInterrupted = false
                await loadStructure()
            } catch {
                phase = .error(error.localizedDescription)
            }
        }
    }

    private func loadStructure() async {
        guard let dm = appState.downloadManager else { return }
        phase = .loadingStructure
        // Fast path: structure persisted at index time — a single SQLite read
        // instead of a SAX pass over the whole volume XML.
        if let pipeline = appState.indexingPipeline,
           let cached = try? await pipeline.cachedVolumeStructure(forVolumeId: volume.volumeId),
           !cached.isEmpty {
            phase = .ready(cached)
            return
        }
        let url = dm.volumeURL(for: volume.volumeId)
        do {
            let structure = try await parser.parseVolumeStructure(volumeURL: url)
            phase = .ready(structure)
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    // MARK: Phase views

    private var notDownloadedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Volume Not Downloaded")
                .font(.headline)
            if volume.sizeBytes > 0 {
                Text("Approx. \(formattedMB(volume.sizeBytes))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Text("Download this volume to browse its chapters, compilations, and documents.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Button {
                guard let dm = appState.downloadManager else { return }
                phase = .downloading
                Task { await dm.enqueueDownload(volumeId: volume.volumeId,
                                                downloadUrl: volume.downloadUrl) }
            } label: {
                Label("Download Volume", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.borderedProminent)
            .disabled(appState.downloadManager == nil)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var downloadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Downloading…")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Indexing will begin automatically when the download completes.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var indexingView: some View {
        // Wrapped in a ScrollView so the discovered-metadata row and the indexing-context
        // card can't be clipped at the corpus-browser window's minimum height (#238 hardening
        // — this phase is not a List, so a ScrollView is the right fix here; the List phases
        // are never wrapped, which would break their own scrolling).
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Indexing Volume", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)
                if let prog = liveProgress, prog.totalDocuments > 0 {
                    ProgressView(value: Double(prog.completedDocuments),
                                 total: Double(prog.totalDocuments))
                    HStack {
                        Text(indexingStageLabel(prog.stage))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(prog.completedDocuments) / \(prog.totalDocuments)")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Preparing…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                if let meta = appState.lastDiscoveredMetadata,
                   meta.volumeId == volume.volumeId {
                    DiscoveredMetadataRow(metadata: meta)
                }
                IndexingContextCard(
                    volume: volume,
                    metadata: appState.lastDiscoveredMetadata.flatMap {
                        $0.volumeId == volume.volumeId ? $0 : nil
                    }
                )
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    private func summaryCardView(_ meta: VolumeMetadataDiscovered) -> some View {
        let title = appState.manifestStore.entry(forVolumeId: meta.volumeId)?.title
        IndexingSummaryCard(
            metadata: meta,
            volumeTitle: title,
            onSearchVolume: { volumeId in
                // Open the Search window DIRECTLY (the MainWindowView relay is retired —
                // provenance PR 2); it inherits this browser's provenance. The browser
                // stays where it is (this view is pushed, not a sheet to dismiss).
                appState.openSearch(SearchParameters(volumeIds: [volumeId]), from: nil)
                appState.bindTool(.search, to: appState.provenance(of: .corpusBrowser))
                openWindow(id: "frus.search")
                bringMacWindowToFront(id: "frus.search")
                appState.completedIndexingMetadata = nil
            },
            onDismiss: {
                showingSummaryCard = false
                appState.completedIndexingMetadata = nil
                Task { await loadStructure() }
            }
        )
    }

    /// Non-blocking banner shown atop a browsable (downloaded) volume when it isn't fully
    /// indexed or a prior pass was interrupted (#214). Unlike the old content walls it does not
    /// hide the structure — it just explains that search / document text need indexing and
    /// offers to run it. `interrupted` takes visual precedence when both apply.
    @ViewBuilder
    private var indexStatusBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isInterrupted ? "exclamationmark.triangle.fill" : "magnifyingglass.circle")
                .foregroundStyle(isInterrupted ? .orange : .secondary)
                .imageScale(.large)
            VStack(alignment: .leading, spacing: 2) {
                Text(isInterrupted
                     ? String(localized: "corpus.volume.indexInterrupted.title",
                              defaultValue: "Indexing Interrupted")
                     : String(localized: "corpus.volume.indexRequired.title",
                              defaultValue: "Not Indexed Yet"))
                    .font(.subheadline.weight(.semibold))
                Text(isInterrupted
                     ? String(localized: "corpus.volume.indexInterrupted.detail",
                              defaultValue: "You can browse this volume's contents now. Re-index it to restore full search coverage and document text.")
                     : String(localized: "corpus.volume.indexRequired.detail",
                              defaultValue: "You can browse this volume's contents now. Index it to search inside it and open its documents."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button {
                indexVolume()
            } label: {
                Label(isInterrupted
                      ? String(localized: "corpus.volume.reindexNow", defaultValue: "Re-index")
                      : String(localized: "corpus.volume.indexNow", defaultValue: "Index"),
                      systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.bordered)
            .disabled(appState.indexingPipeline == nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background((isInterrupted ? Color.orange : Color.secondary).opacity(0.12))
    }

    /// Flattens front-matter sections for display under the "Front Matter" header.
    ///
    /// A `"front"` wrapper is expanded so its subsections appear directly (one fewer
    /// tap); a wrapper carrying direct documents (1861-era volumes place the
    /// President's annual message in `<front>`) is kept alongside them. Any other
    /// top-level section whose kind is front matter is included as-is.
    private static func extractFrontMatter(from sections: [VolumeSection]) -> [VolumeSection] {
        var items: [VolumeSection] = []
        for section in sections {
            if section.divType == "front" {
                if section.subsections.isEmpty || !section.documentIds.isEmpty {
                    items.append(section)
                }
                items.append(contentsOf: section.subsections)
            } else if section.isFrontMatterKind {
                items.append(section)
            }
        }
        return items
    }

    /// Flattens back-matter sections (errata, index) by expanding the `<back>`
    /// wrapper, mirroring `extractFrontMatter`.
    private static func extractBackMatter(from sections: [VolumeSection]) -> [VolumeSection] {
        var items: [VolumeSection] = []
        for section in sections where section.divType == "back" {
            if section.subsections.isEmpty || !section.documentIds.isEmpty {
                items.append(section)
            }
            items.append(contentsOf: section.subsections)
        }
        return items
    }

    /// Handles a tap on a section row in the volume structure list.
    ///
    /// Prose-readable sections (preface, introduction, errata, etc.) open straight
    /// into this browser's provenance host on the first tap — the same one-tap behaviour
    /// as a numbered document — via `AppState.openDocument(_:from: .tool(.corpusBrowser))`.
    /// Sections that need an intermediate list or a structured view (compilations with
    /// documents, the Persons glossary, the Sources list) push `CorpusSectionDocumentView`
    /// onto the detail-column path instead.
    private func openSection(_ section: VolumeSection) {
        if section.canReadDirectly {
            appState.openDocument(DocumentBrowserEntry(
                documentId: section.sectionId,
                volumeId: volume.volumeId,
                header: section.title
            ), from: .tool(.corpusBrowser), using: openWindow)
        } else {
            path.append(.section(volumeId: volume.volumeId, section: section))
        }
    }

    @ViewBuilder
    private func structureView(_ structure: VolumeStructure) -> some View {
        if structure.isEmpty {
            ContentUnavailableView(
                "No Contents",
                systemImage: "doc.text",
                description: Text("No structural sections were found in this volume.")
            )
        } else {
            let frontMatterItems = Self.extractFrontMatter(from: structure.sections)
            let backMatterItems = Self.extractBackMatter(from: structure.sections)
            let contentSections = structure.sections.filter {
                !$0.isFrontMatterKind && $0.divType != "back"
            }
            VStack(spacing: 0) {
            if !isVolumeIndexed || isInterrupted {
                indexStatusBanner
                Divider()
            }
            List {
                if !frontMatterItems.isEmpty {
                    Section("Front Matter") {
                        ForEach(frontMatterItems) { section in
                            Button { openSection(section) } label: {
                                SectionRowLabel(section: section)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !contentSections.isEmpty {
                    Section("Contents") {
                        ForEach(contentSections) { section in
                            Button { openSection(section) } label: {
                                SectionRowLabel(section: section)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !backMatterItems.isEmpty {
                    Section("Back Matter") {
                        ForEach(backMatterItems) { section in
                            Button { openSection(section) } label: {
                                SectionRowLabel(section: section)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.inset)
            }
        }
    }

    // MARK: Helpers

    private func formattedMB(_ bytes: Int) -> String {
        String(format: "%.0f MB", Double(bytes) / 1_000_000)
    }

    private func indexingStageLabel(_ stage: IndexingStage) -> String {
        switch stage {
        case .reading:
            return String(localized: "corpus.detail.indexing.stage.reading",
                          defaultValue: "Reading…")
        case .storingBatch(let current, let total):
            return String(localized: "corpus.detail.indexing.stage.storingBatch",
                          defaultValue: "Storing batch \(current) of \(total)…")
        case .optimizing:
            return String(localized: "corpus.detail.indexing.stage.optimizing",
                          defaultValue: "Finalizing index…")
        case .complete:
            return String(localized: "corpus.detail.indexing.stage.complete",
                          defaultValue: "Complete")
        }
    }
}

// MARK: - DiscoveredMetadataRow

/// Two-column grid of aggregate discovery counts shown inside `CorpusVolumeDetailView`
/// once `VolumeMetadataDiscovered` arrives from the pipeline's metadata stream.
///
/// Omits any row whose value is zero. Includes a date-range line when present.
///
/// Version history:
///   1.0 — Session 113: initial implementation
private struct DiscoveredMetadataRow: View {
    let metadata: VolumeMetadataDiscovered

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 4) {
                if metadata.uniquePersonCount > 0 {
                    GridRow {
                        Text("Persons")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(metadata.uniquePersonCount)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                }
                if metadata.crossReferenceCount > 0 {
                    GridRow {
                        Text("Cross-references")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(metadata.crossReferenceCount)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                }
                if metadata.datedDocumentCount > 0 {
                    GridRow {
                        Text("Dated")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(metadata.datedDocumentCount) / \(metadata.totalDocuments)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                }
                if metadata.editorialNoteCount > 0 {
                    GridRow {
                        Text("Editorial notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(metadata.editorialNoteCount)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                }
            }
            if let dateRange = formattedDateRange {
                Text(dateRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var formattedDateRange: String? {
        guard let minISO = metadata.dateRangeMin,
              let maxISO = metadata.dateRangeMax else { return nil }
        let minFormatted = formatISODate(minISO) ?? minISO
        let maxFormatted = formatISODate(maxISO) ?? maxISO
        return "\(minFormatted) – \(maxFormatted)"
    }

    private func formatISODate(_ iso: String) -> String? {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: iso) else { return nil }
        let out = DateFormatter()
        out.dateFormat = "MMM yyyy"
        return out.string(from: date)
    }
}

// MARK: - CorpusSectionDocumentView

/// The content for a single section, pushed into the corpus browser window's detail column
/// from `CorpusVolumeDetailView`.
///
/// Routes to the appropriate view based on section type:
/// - **Prose sections** (`preface`, `intro`, `introduction`, `errata`, `prefatoryNote`,
///   `terms`) with an explicit `xml:id` show a "Read" button that opens the section as a
///   document.
/// - **`"persons"`** sections embed `FrontMatterPersonsView` inside a `List` (since that
///   view emits `Section` content rather than a root container).
/// - **`"sources"`** sections embed `VolumeSourcesView` inside a `List` for the same reason.
/// - All other sections fetch the indexed document list and display rows.
///
/// Tapping a document (or the "Read" button) routes the entry to this browser's provenance
/// host via `AppState.openDocument(_:from: .tool(.corpusBrowser))`; the browser window
/// stays where it is. The system back button returns to the volume overview.
///
/// Version history:
///   1.0 — Session 11: initial implementation (document list only)
///   1.1 — Session 2026-06-09: front-matter routing — persons, sources, prose sections
///   1.2 — Session 170: pushed into the detail column instead of presented as a sheet
///   1.3 — Session 2026-07-03: full-title header above the routed content — the window
///          title truncates long chapter/compilation titles
///   1.4 — Session 2026-07-04 (Source Explorer Phase 5 S6): the Archival Neighbors
///          sheet for volume-source rows removed — `VolumeSourcesView` opens the
///          value-based Archival Neighbors window directly on macOS, so the hoisted
///          binding is never set here anymore
///   1.5 — Session 2026-07-04 (macOS UI audit B2): the Cross-Volume Provenance sheet
///          removed the same way — `VolumeSourcesView` opens the value-based
///          Cross-Volume Provenance window directly on macOS, so `crossVolumeTarget`
///          is never set here anymore either
///   1.6 — Session 2026-07-08: the full-title header is now `BoundedTitleHeader` (height
///          capped, scrolls when longer) — an unbounded `fixedSize` title overflowed the
///          non-scrolling column and blanked the section's contents for long chapter titles
private struct CorpusSectionDocumentView: View {
    let volumeId: String
    let section: VolumeSection
    /// The window's detail-column path; a subsection row pushes deeper onto it.
    @Binding var path: [CorpusNavValue]

    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    @State private var documents: [DocumentBrowserEntry] = []
    @State private var isLoading = true
    /// Whether this section's volume is indexed. Defaults `true` so an indexed volume never
    /// flashes the prompt; set in `loadDocuments`. When `false`, an empty leaf section shows an
    /// "index to view documents" prompt instead of the misleading "No documents" (#214), since
    /// the document list reads `document_cache`, which is only populated for indexed volumes.
    @State private var volumeIndexed = true
    /// Hoisted presentation targets for the section-emitting front-matter subviews —
    /// the sheets anchor on this view's Lists, exactly once (see the body comments).
    /// `sourceNeighborsTarget` and `crossVolumeTarget` are required by
    /// `VolumeSourcesView`'s shared init but are never written on macOS (S6/B2): the
    /// row actions open the Archival Neighbors / Cross-Volume Provenance windows
    /// directly, so no sheets anchor for them here.
    @State private var sourceNeighborsTarget: VolumeSourceNeighborsTarget? = nil
    @State private var crossVolumeTarget: CrossVolumeTarget? = nil
    /// Hoisted Collection-detail target (Phase 4) — presented on this view's List.
    @State private var collectionDetailTarget: AuthorityCollectionRecord? = nil
    @State private var selectedPerson: PersonIndexEntry? = nil

    // MARK: - Section Routing

    /// `true` when this section is a prose-only front-matter div that can be opened
    /// directly as a document, bypassing the indexed document list.
    private var canReadSectionDirectly: Bool { section.canReadDirectly }

    /// `true` when this section is the structured Persons list.
    private var isPersonsSection: Bool { section.isPersonsList }

    /// `true` when this section is the structured archival Sources list.
    private var isSourcesSection: Bool { section.isSourcesList }

    // MARK: - Body

    var body: some View {
        // Pushed into the browser window's resizable detail column (not a sheet), so the
        // title comes from `.navigationTitle` and the system back button handles dismissal.
        // The full section title heads the content — the window/navigation title truncates
        // long chapter/compilation titles, so the complete value must be readable here.
        // `BoundedTitleHeader` caps that header's height so a paragraph-length title can't
        // push the routed content (document list / persons / sources) out of the
        // non-scrolling column.
        VStack(alignment: .leading, spacing: 0) {
            BoundedTitleHeader(title: section.title)
            Divider()
            sectionContent
        }
        .navigationTitle(section.title)
        .task {
            // Skip the document-list fetch for sections handled by dedicated views.
            if canReadSectionDirectly || isPersonsSection || isSourcesSection {
                isLoading = false
            } else {
                await loadDocuments()
            }
        }
        // Live-refresh the document list / "index to view documents" prompt when indexing
        // completes externally while the user is inside this section of a not-yet-indexed
        // volume (#214 review). Only re-fetch for the structural document path.
        .onChange(of: appState.currentIndexingProgress) { _, progress in
            if progress == nil, !volumeIndexed,
               !(canReadSectionDirectly || isPersonsSection || isSourcesSection) {
                Task { await loadDocuments() }
            }
        }
    }

    /// The routed per-kind content (prose Read button, persons list, sources list, or the
    /// structural subsection/document list) shown below the full-title header.
    @ViewBuilder
    private var sectionContent: some View {
        Group {
            if canReadSectionDirectly {
                proseSectionView
            } else if isPersonsSection {
                // FrontMatterPersonsView emits Section content and must live inside a List.
                // Its detail sheet anchors HERE on the List — presentation modifiers inside
                // section-emitting list content apply per row (the Archival Neighbors
                // open/close-loop class), so the subview only sets the binding.
                List { FrontMatterPersonsView(volumeId: volumeId, selectedPerson: $selectedPerson) }
                    .listStyle(.inset)
                    .sheet(item: $selectedPerson) { entry in
                        PersonIndexDetailSheet(indexEntry: entry)
                    }
            } else if isSourcesSection {
                // VolumeSourcesView emits Section content and must live inside a List.
                // The remaining sheet anchors HERE on the List (see above). No sheets
                // for `sourceNeighborsTarget` / `crossVolumeTarget`: on macOS those
                // row affordances open the S6 Archival Neighbors / B2 Cross-Volume
                // Provenance windows directly, so the bindings are never set (they
                // exist only for the shared iOS init).
                List {
                    VolumeSourcesView(volumeId: volumeId,
                                      sourceNeighborsTarget: $sourceNeighborsTarget,
                                      crossVolumeTarget: $crossVolumeTarget,
                                      collectionDetailTarget: $collectionDetailTarget)
                }
                .listStyle(.inset)
                .sheet(item: $collectionDetailTarget) { record in
                    CollectionDetailSheet(record: record)
                        .environment(appState)
                }
            } else {
                structuralList
            }
        }
    }

    /// Prose front-matter section — a single "Read" action that opens it in the main window.
    private var proseSectionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(String(localized: "corpus.section.proseSection",
                        defaultValue: "Prose Section"))
                .font(.headline)
            Text(String(localized: "corpus.section.proseSection.detail",
                        defaultValue: "This section contains prose content rather than individual numbered documents."))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Button {
                appState.openDocument(DocumentBrowserEntry(
                    documentId: section.sectionId,
                    volumeId: volumeId,
                    documentNumber: nil,
                    header: section.title,
                    dateline: nil,
                    sourceNote: nil
                ), from: .tool(.corpusBrowser), using: openWindow)
            } label: {
                Label(
                    String(
                        format: String(localized: "browser.compilation.readSection",
                                       defaultValue: "Read %@"),
                        section.title
                    ),
                    systemImage: "doc.text"
                )
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    /// A structural section: its child subsections as drill-down rows, plus its own *direct*
    /// documents — mirroring history.state.gov, where an interior grouping node shows its
    /// child groups (and any documents attached directly to it), while a leaf lists its
    /// documents. Drilling into a subsection pushes a deeper `CorpusSectionDocumentView`, so
    /// arbitrarily-nested volumes work with no new screens.
    @ViewBuilder
    private var structuralList: some View {
        List {
            if !section.subsections.isEmpty {
                Section(String(localized: "corpus.section.subsections", defaultValue: "Sections")) {
                    ForEach(section.subsections) { sub in
                        Button {
                            path.append(.section(volumeId: volumeId, section: sub))
                        } label: {
                            SectionRowLabel(section: sub)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if isLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text(String(localized: "corpus.section.loading", defaultValue: "Loading…"))
                            .foregroundStyle(.secondary)
                    }
                }
            } else if !documents.isEmpty {
                Section(String(format: String(localized: "corpus.section.documents %lld",
                                              defaultValue: "Documents (%lld)"), Int64(documents.count))) {
                    ForEach(documents, id: \.documentId) { doc in
                        documentButton(doc)
                    }
                }
            } else if section.subsections.isEmpty {
                Section {
                    if volumeIndexed {
                        Text(String(localized: "corpus.section.noDocuments",
                                    defaultValue: "No documents in this section."))
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(localized: "corpus.section.needsIndex",
                                        defaultValue: "This volume isn't indexed yet."))
                                .foregroundStyle(.secondary)
                            Text(String(localized: "corpus.section.needsIndex.detail",
                                        defaultValue: "Index the volume (from the banner atop its contents) to view and open its documents."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    /// A tappable document row that opens the document in this browser's provenance host.
    private func documentButton(_ doc: DocumentBrowserEntry) -> some View {
        Button {
            appState.openDocument(doc, from: .tool(.corpusBrowser), using: openWindow)
        } label: {
            DocumentRowLabel(doc: doc)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                appState.currentGraphEntry = doc
                appState.bindTool(.graph, to: appState.provenance(of: .corpusBrowser))
                openWindow(id: "frus.crossReferenceGraph")
            } label: {
                Label("Show Cross-Reference Graph",
                      systemImage: "point.3.connected.trianglepath.dotted")
            }
        }
    }

    private func loadDocuments() async {
        guard let pipeline = appState.indexingPipeline else {
            volumeIndexed = false; isLoading = false; return
        }
        volumeIndexed = (try? pipeline.isVolumeIndexed(volumeId)) == true
        let all = (try? await pipeline.documents(forVolume: volumeId)) ?? []
        // Direct documents only (`documentIds`, not `allDocumentIds`); subsections list and
        // load their own, so a compilation with chapters isn't flattened into one long list.
        let sectionIds = Set(section.documentIds)
        documents = all.filter { sectionIds.contains($0.documentId) }
        isLoading = false
    }
}

#endif // os(macOS)
