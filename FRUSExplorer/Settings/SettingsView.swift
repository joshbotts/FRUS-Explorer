// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - SettingsView

/// Root Settings screen.
///
/// ## Layout
/// `Form` inside a `NavigationStack`. Each panel is a `NavigationLink` to a dedicated
/// sub-view. Panels are grouped into functional sections matching the specification.
///
/// ## Panels
/// | Panel | Sub-view |
/// |---|---|
/// | Downloads | `DownloadsSettingsView` |
/// | Storage management | `StorageManagementView` |
/// | Sideload | `SideloadView` |
/// | Reindex | `ReindexView` |
/// | User tags | `UserTagsView` |
/// | Summarization prompts | `SummarizationPromptsSettingsView` |
/// | NARA API key | `NARAKeyView` |
/// | Reset | `ResetView` |
///
/// ## Log prefix
/// `[Settings]`
///
/// Version history:
///   1.0 — Session 24: initial implementation
///   1.1 — Session 26: add About row
///   1.2 — Session 35: fix macOS blank NavigationLink destinations via frame expansion
///   1.3 — Session 44: Done button and dismiss guarded to non-iOS (Settings is a tab on iOS)
///   1.4 — Session 49: Download Manager row added to Volumes section
///   1.5 — Session 50: About row removed from iOS SettingsView (now in macOS App menu)
///   1.6 — Session 57: VolumeManagementView delete moved to swipe action + confirmation dialog
///          (F-010); UserTagsView gains leading swipe-to-rename action (F-004)
///   1.7 — Session 67: macOS scroll affordances for all detail panes (remove maxHeight:
///          .infinity from Form so NavigationSplitView detail column bounds it correctly;
///          add .scrollIndicators(.visible)); StorageManagementView adds per-volume
///          indexing-status badge and Reindex button via IndexingPipeline API
///   1.8 — Session 70: fix three macOS Settings issues: (a) VolumeManagementView
///          Available Volumes section gains a live search filter so 552 entries don't
///          fill the view — only matching results are shown; title text gets lineLimit(2)
///          to prevent horizontal overflow; (b) StorageManagementView perVolumeRow
///          redesigned from one wide HStack to a two-line VStack (title+size on row 1,
///          volumeId+indexed-status on row 2) so it fits narrow detail columns; (c) macOS
///          MacSettingsView switches from the newer Tab API to the stable .tabItem API
///          (fixes Advanced tab not appearing); .navigationSplitViewStyle(.balanced) added
///          to all three panes to prevent sidebar auto-collapse on minimum-width windows;
///          minWidth increased from 700 → 760 to give detail columns more breathing room
///   1.9 — Session 90: General section added to iOS with Display and Search Defaults panes
///          (close gap with macOS FRUSSettingsView); storage limit picker added to
///          StorageManagementView (matches macOS Storage pane)
///   2.0 — Session 101: Log Research Sessions toggle added to Research section
///   2.1 — Session 115: ReindexView gains "Needs Attention" section for interrupted volumes
///   2.2 — Session 117: Download Manager row removed; Volume Management renamed to Downloads
///          and replaced by DownloadsSettingsView (merged scope picker + browse list)
struct SettingsView: View {

    #if !os(iOS)
    @Environment(\.dismiss) private var dismiss
    #endif

    @AppStorage("researchSessionLoggingEnabled") private var loggingEnabled = true

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "settings.section.general",
                               defaultValue: "General")) {
                    NavigationLink(String(localized: "settings.row.display",
                                         defaultValue: "Display")) {
                        DisplaySettingsView()
                    }
                    NavigationLink(String(localized: "settings.row.searchDefaults",
                                         defaultValue: "Search Defaults")) {
                        SearchDefaultsView()
                    }
                }

                Section(String(localized: "settings.section.volumes",
                               defaultValue: "Volumes")) {
                    NavigationLink(String(localized: "settings.row.downloads",
                                         defaultValue: "Downloads")) {
                        DownloadsSettingsView()
                    }
                    NavigationLink(String(localized: "settings.row.storage",
                                         defaultValue: "Storage")) {
                        StorageManagementView()
                    }
                    NavigationLink(String(localized: "settings.row.sideload",
                                         defaultValue: "Sideload Volume")) {
                        SideloadView()
                    }
                    NavigationLink(String(localized: "settings.row.reindex",
                                         defaultValue: "Reindex")) {
                        ReindexView()
                    }
                }

                Section(String(localized: "settings.section.research",
                               defaultValue: "Research")) {
                    NavigationLink(String(localized: "settings.row.tags",
                                         defaultValue: "User Tags")) {
                        UserTagsView()
                    }
                    NavigationLink(String(localized: "settings.row.summarization",
                                         defaultValue: "Summarization Prompts")) {
                        SummarizationPromptsSettingsView()
                    }
                    Toggle(
                        String(localized: "settings.row.logSessions",
                               defaultValue: "Log Research Sessions"),
                        isOn: $loggingEnabled
                    )
                }

                Section(String(localized: "settings.section.integrations",
                               defaultValue: "Integrations")) {
                    NavigationLink(String(localized: "settings.row.naraKey",
                                         defaultValue: "NARA Catalog API Key")) {
                        NARAKeyView()
                    }
                }

                Section {
                    NavigationLink(String(localized: "settings.row.reset",
                                         defaultValue: "Reset App")) {
                        ResetView()
                    }
                    .foregroundStyle(.red)
                }

                #if os(iOS)
                Section {
                    NavigationLink(String(localized: "settings.row.about",
                                         defaultValue: "About FRUS Explorer")) {
                        AboutView()
                    }
                }
                #endif
            }
            .navigationTitle(String(localized: "settings.title", defaultValue: "Settings"))
            // HIG: top-level destination screens use .large title to match system weight.
            // Child panes (VolumeManagementView, StorageManagementView, etc.) keep .inline.
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                #if !os(iOS)
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "settings.done", defaultValue: "Done")) {
                        dismiss()
                    }
                }
                #endif
            }
        }
        #if os(macOS)
        // Provides stable minimum dimensions for the settings sheet on macOS so that
        // NavigationLink destinations inherit a proper sized container and render correctly.
        .frame(minWidth: 500, minHeight: 440)
        #endif
    }
}

// MARK: - DownloadsSettingsView

/// Combined Downloads settings pane.
///
/// Merges the former `DownloadManagerSettingsView` (bulk/scoped enqueue) and
/// `VolumeManagementView` (browse-and-pick, queue state, delete) into one
/// scrollable destination reachable from Settings → Volumes → Downloads.
///
/// ## Section order
/// 1. **Active Downloads** — suppressed entirely when the queue is idle.
/// 2. **Find Volumes** — scope picker + enqueue button, followed by the per-volume
///    browse list. Footer explains the two interaction styles.
/// 3. **Downloaded Volumes** — swipe-to-delete with confirmation dialog.
/// 4. **Settings** — concurrent downloads picker.
/// 5. **Check for New Volumes** — button that refreshes the live manifest.
///
/// Version history:
///   1.0 — Session 117: merged from VolumeManagementView (Session 49, 51, 70) and
///          DownloadManagerSettingsView (Session 49, 67)
private struct DownloadsSettingsView: View {

    @Environment(AppState.self) private var appState

    // MARK: Browse / delete state (from VolumeManagementView)

    @State private var concurrentDownloadLimit: Int = {
        let stored = UserDefaults.standard.integer(forKey: SettingsKeys.concurrentDownloadLimit)
        return stored > 0 ? stored : 4
    }()
    @State private var volumePendingDelete: VolumeManifestEntry? = nil
    @State private var availableSearch: String = ""
    @State private var showAllAvailable: Bool = false
    private let availablePageSize: Int = 50

    // MARK: Scope-enqueue state (from DownloadManagerSettingsView)

    @State private var selectedScope: DownloadScope = .corpus
    @State private var selectedSubseries: String = ""
    @State private var singleVolumeSearch: String = ""
    @State private var enqueuedMessage: String? = nil

    var body: some View {
        Form {
            // 1. Active Downloads — hidden when queue is idle.
            if !appState.downloadQueue.isEmpty {
                Section(String(localized: "settings.volumes.active.header",
                               defaultValue: "Active Downloads")) {
                    activeDownloadsSection
                }
            }

            // 2. Find Volumes — scope picker + enqueue + browse list.
            Section(
                header: Text(String(localized: "downloads.findVolumes.header",
                                    defaultValue: "Find Volumes")),
                footer: Text(String(localized: "downloads.findVolumes.footer",
                                    defaultValue: "Use the scope selector to enqueue a group at once, or search and download volumes individually below."))
            ) {
                Picker(
                    String(localized: "settings.downloadManager.scope.label",
                           defaultValue: "Scope"),
                    selection: Binding(
                        get: { scopePickerTag },
                        set: { tag in
                            switch tag {
                            case 0: selectedScope = .corpus
                            case 1: selectedScope = .subseries(selectedSubseries)
                            case 2: selectedScope = .volume(singleVolumeSearch.trimmingCharacters(in: .whitespacesAndNewlines))
                            default: break
                            }
                        }
                    )
                ) {
                    Text(String(localized: "settings.downloadManager.scope.corpus",
                                defaultValue: "Entire Corpus")).tag(0)
                    Text(String(localized: "settings.downloadManager.scope.subseries",
                                defaultValue: "By Subseries")).tag(1)
                    Text(String(localized: "settings.downloadManager.scope.volume",
                                defaultValue: "Single Volume")).tag(2)
                }

                if case .subseries = selectedScope {
                    Picker(
                        String(localized: "settings.downloadManager.subseries.label",
                               defaultValue: "Subseries"),
                        selection: $selectedSubseries
                    ) {
                        Text(String(localized: "settings.downloadManager.subseries.placeholder",
                                    defaultValue: "Select…")).tag("")
                        ForEach(allSubseries, id: \.self) { s in
                            Text(s).tag(s)
                        }
                    }
                    .onChange(of: selectedSubseries) { _, newValue in
                        selectedScope = .subseries(newValue)
                    }
                }

                if case .volume = selectedScope {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField(
                            String(localized: "settings.downloadManager.volume.placeholder",
                                   defaultValue: "Title or volume ID…"),
                            text: $singleVolumeSearch
                        )
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .onChange(of: singleVolumeSearch) { _, newValue in
                            selectedScope = .volume(newValue.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                    }
                    ForEach(singleVolumeResults) { entry in
                        Button {
                            singleVolumeSearch = entry.volumeId
                            selectedScope = .volume(entry.volumeId)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title).font(.callout).foregroundStyle(.primary).lineLimit(1)
                                    Text(entry.volumeId).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if case .volume(let id) = selectedScope, id == entry.volumeId {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    enqueue()
                } label: {
                    Label(
                        String(localized: "settings.downloadManager.enqueue.button",
                               defaultValue: "Download"),
                        systemImage: "arrow.down.circle"
                    )
                }
                .disabled(!canEnqueue)
                .accessibilityLabel(
                    String(localized: "settings.downloadManager.enqueue.a11y",
                           defaultValue: "Start downloading selected volumes")
                )

                if let msg = enqueuedMessage {
                    Label(msg, systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                        .font(.callout)
                }

                Divider()

                availableVolumesSection
            }

            // 3. Downloaded Volumes.
            Section(String(localized: "settings.volumes.downloaded.header",
                           defaultValue: "Downloaded Volumes")) {
                downloadedVolumesSection
            }

            // 4. Settings.
            Section(String(localized: "downloads.settings.header",
                           defaultValue: "Settings")) {
                Picker(
                    String(localized: "settings.volumes.concurrentLimit.label",
                           defaultValue: "Concurrent Downloads"),
                    selection: $concurrentDownloadLimit
                ) {
                    ForEach([1, 2, 3, 4, 6], id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
                .onChange(of: concurrentDownloadLimit) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: SettingsKeys.concurrentDownloadLimit)
                    #if DEBUG
                    print("[Settings] Concurrent download limit set to \(newValue) (takes effect on next launch)")
                    #endif
                }
                .accessibilityLabel(
                    String(localized: "settings.volumes.concurrentLimit.a11y",
                           defaultValue: "Concurrent download limit")
                )
                Text(String(localized: "settings.volumes.concurrentLimit.note",
                            defaultValue: "Takes effect on next launch."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 5. Check for New Volumes.
            Section {
                Button {
                    Task { await appState.manifestStore.fetchLiveManifest() }
                } label: {
                    Label(
                        String(localized: "settings.volumes.checkNew.button",
                               defaultValue: "Check for New Volumes"),
                        systemImage: "arrow.clockwise"
                    )
                }
                .accessibilityLabel(
                    String(localized: "settings.volumes.checkNew.a11y",
                           defaultValue: "Check for new FRUS volumes")
                )
            }
        }
        .navigationTitle(String(localized: "downloads.navigationTitle",
                                defaultValue: "Downloads"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .frame(maxWidth: .infinity)
        .scrollIndicators(.visible)
        #endif
        .confirmationDialog(
            String(localized: "settings.volumes.delete.confirm.title",
                   defaultValue: "Delete Volume?"),
            isPresented: Binding(
                get: { volumePendingDelete != nil },
                set: { if !$0 { volumePendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: volumePendingDelete
        ) { entry in
            Button(String(localized: "settings.volumes.delete.confirm.action",
                          defaultValue: "Delete"),
                   role: .destructive) {
                Task { try? await appState.downloadManager?.deleteVolume(volumeId: entry.volumeId) }
                volumePendingDelete = nil
            }
            Button(String(localized: "settings.volumes.delete.confirm.cancel",
                          defaultValue: "Cancel"),
                   role: .cancel) {
                volumePendingDelete = nil
            }
        } message: { entry in
            Text(String(
                format: String(localized: "settings.volumes.delete.confirm.message",
                               defaultValue: "\"%@\" will be removed from your device. You can re-download it later."),
                entry.title
            ))
        }
    }

    // MARK: - Section builders

    @ViewBuilder
    private var activeDownloadsSection: some View {
        ForEach(appState.downloadQueue, id: \.self) { volumeId in
            HStack {
                Text(volumeId)
                    .font(.callout)
                Spacer()
                Button(String(localized: "settings.volumes.active.cancel",
                              defaultValue: "Cancel")) {
                    Task {
                        await appState.downloadManager?.cancelDownload(volumeId: volumeId)
                    }
                }
                .font(.callout)
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
                .accessibilityLabel(
                    String(localized: "settings.volumes.active.cancel.a11y",
                           defaultValue: "Cancel download for \(volumeId)")
                )
            }
        }
    }

    @ViewBuilder
    private var downloadedVolumesSection: some View {
        let downloaded = downloadedVolumes
        if downloaded.isEmpty {
            Text(String(localized: "settings.volumes.downloaded.empty",
                        defaultValue: "No downloaded volumes."))
                .foregroundStyle(.secondary)
                .font(.callout)
        } else {
            ForEach(downloaded) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(.callout)
                        .lineLimit(2)
                    Text(entry.volumeId)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        volumePendingDelete = entry
                    } label: {
                        Label(
                            String(localized: "settings.volumes.downloaded.delete",
                                   defaultValue: "Delete"),
                            systemImage: "trash"
                        )
                    }
                    .accessibilityLabel(
                        String(localized: "settings.volumes.downloaded.delete.a11y",
                               defaultValue: "Delete \(entry.title)")
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var availableVolumesSection: some View {
        let notDownloaded = notDownloadedVolumes
        if notDownloaded.isEmpty {
            Text(String(localized: "settings.volumes.available.empty",
                        defaultValue: "All known volumes are downloaded."))
                .foregroundStyle(.secondary)
                .font(.callout)
        } else {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                TextField(
                    String(localized: "settings.volumes.available.search.placeholder",
                           defaultValue: "Search by title, ID, or subseries…"),
                    text: $availableSearch
                )
                .textFieldStyle(.plain)
                .font(.callout)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                if !availableSearch.isEmpty {
                    Button {
                        availableSearch = ""
                        showAllAvailable = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        String(localized: "settings.volumes.available.search.clear.a11y",
                               defaultValue: "Clear search")
                    )
                }
            }
            .padding(.vertical, 2)
            .onChange(of: availableSearch) { _, newValue in
                if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    showAllAvailable = false
                }
            }

            let filtered = availableFiltered(notDownloaded)
            if filtered.isEmpty {
                Text(String(
                    format: String(localized: "settings.volumes.available.noResults",
                                   defaultValue: "No volumes match \"%@\"."),
                    availableSearch
                ))
                .foregroundStyle(.secondary)
                .font(.callout)
            } else {
                let isSearchActive = !availableSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let displayRows = isSearchActive || showAllAvailable
                    ? filtered
                    : Array(filtered.prefix(availablePageSize))

                ForEach(displayRows) { entry in
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                                .font(.callout)
                                .lineLimit(2)
                            Text(entry.volumeId)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(formattedBytes(entry.sizeBytes))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer(minLength: 8)
                        Button(String(localized: "settings.volumes.available.download",
                                      defaultValue: "Download")) {
                            let url = "https://raw.githubusercontent.com/HistoryAtState/frus/master/volumes/\(entry.filename)"
                            Task {
                                await appState.downloadManager?.enqueueDownload(
                                    volumeId: entry.volumeId,
                                    downloadUrl: url)
                            }
                        }
                        .font(.callout)
                        .buttonStyle(.borderless)
                        .accessibilityLabel(
                            String(localized: "settings.volumes.available.download.a11y",
                                   defaultValue: "Download \(entry.title)")
                        )
                    }
                }

                if !isSearchActive && !showAllAvailable && filtered.count > availablePageSize {
                    Button {
                        showAllAvailable = true
                    } label: {
                        Text(String(
                            format: String(localized: "settings.volumes.available.showAll",
                                           defaultValue: "Show all %lld volumes…"),
                            filtered.count
                        ))
                        .font(.callout)
                        .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Helpers

    private var allSubseries: [String] {
        let source = appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
        return Set(source.map(\.subseries)).sorted { lhsYear(from: $0) > lhsYear(from: $1) }
    }

    private func lhsYear(from subseries: String) -> Int {
        Int(subseries.prefix(4)) ?? 0
    }

    private var singleVolumeResults: [VolumeManifestEntry] {
        let query = singleVolumeSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let lower = query.lowercased()
        let source = appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
        return source.filter {
            $0.title.lowercased().contains(lower) || $0.volumeId.lowercased().contains(lower)
        }.prefix(20).map { $0 }
    }

    private var canEnqueue: Bool {
        guard appState.downloadManager != nil else { return false }
        switch selectedScope {
        case .corpus:         return true
        case .subseries:      return !selectedSubseries.isEmpty
        case .volume(let id): return !id.isEmpty
        }
    }

    private var scopePickerTag: Int {
        switch selectedScope {
        case .corpus:    return 0
        case .subseries: return 1
        case .volume:    return 2
        }
    }

    private func enqueue() {
        guard let dm = appState.downloadManager else { return }
        enqueuedMessage = nil
        let source = appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
        let toEnqueue: [VolumeManifestEntry]
        switch selectedScope {
        case .corpus:
            toEnqueue = source
        case .subseries(let id):
            toEnqueue = source.filter { $0.subseries == id }
        case .volume(let id):
            toEnqueue = source.filter { $0.volumeId == id }
        }
        Task {
            for entry in toEnqueue {
                let url = "https://raw.githubusercontent.com/HistoryAtState/frus/master/volumes/\(entry.filename)"
                await dm.enqueueDownload(volumeId: entry.volumeId, downloadUrl: url)
            }
            await MainActor.run {
                let count = toEnqueue.count
                enqueuedMessage = String(
                    localized: "settings.downloadManager.enqueued",
                    defaultValue: "\(count) volume\(count == 1 ? "" : "s") queued for download.")
            }
            #if DEBUG
            print("[Settings] Downloads enqueued \(toEnqueue.count) volumes.")
            #endif
        }
    }

    private func availableFiltered(_ volumes: [VolumeManifestEntry]) -> [VolumeManifestEntry] {
        let q = availableSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return volumes }
        let lower = q.lowercased()
        return volumes.filter {
            $0.title.lowercased().contains(lower)
            || $0.volumeId.lowercased().contains(lower)
            || $0.subseries.lowercased().contains(lower)
        }
    }

    private var downloadedVolumes: [VolumeManifestEntry] {
        guard let dm = appState.downloadManager else { return [] }
        let all = appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
        return all.filter { dm.isVolumeDownloaded($0.volumeId) }
    }

    private var notDownloadedVolumes: [VolumeManifestEntry] {
        guard let dm = appState.downloadManager else { return [] }
        let all = appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
        return all.filter { !dm.isVolumeDownloaded($0.volumeId) }
    }
}

// MARK: - StorageManagementView

/// Shows aggregate and per-volume storage usage.
///
/// ## Indexing Status (Session 67)
/// Each per-volume row indicates whether the volume has been indexed for full-text
/// search (using `IndexingPipeline.isVolumeIndexed`). Unindexed volumes display a
/// "Reindex" button that calls `IndexingPipeline.indexVolume` inline.
///
/// ## Scroll Affordance (Session 67)
/// The Form omits `maxHeight: .infinity` so the `NavigationSplitView` detail column
/// bounds it correctly and it scrolls when the per-volume list is long.
private struct StorageManagementView: View {

    @Environment(AppState.self) private var appState

    @State private var report: StorageReport? = nil
    @State private var loadError: String? = nil

    /// Indexed status per volumeId. `nil` means not yet checked or pipeline unavailable.
    @State private var indexedStatus: [String: Bool] = [:]
    /// VolumeId currently being reindexed; drives inline ProgressView.
    @State private var reindexingVolumeId: String? = nil
    /// Per-volume reindex errors (rare, but surfaced inline).
    @State private var reindexErrors: [String: String] = [:]

    @AppStorage("frus.storage.limitGB") private var storageLimitGB: Int = 0

    var body: some View {
        Form {
            Section(header: EmptyView(),
                    footer: Text(String(localized: "settings.storage.limit.footer",
                                        defaultValue: "The app will warn before downloads exceed this threshold. The full FRUS corpus is approximately 3.4 GB."))) {
                Picker(String(localized: "settings.storage.limit.label",
                              defaultValue: "On-Device Limit"),
                       selection: $storageLimitGB) {
                    Text("1 GB").tag(1)
                    Text("2 GB").tag(2)
                    Text("3 GB").tag(3)
                    Text(String(localized: "settings.storage.limit.none",
                                defaultValue: "No Limit")).tag(0)
                }
                .accessibilityLabel(
                    String(localized: "settings.storage.limit.a11y",
                           defaultValue: "On-device storage limit")
                )
            }

            Section(String(localized: "settings.storage.aggregate.header",
                           defaultValue: "Total Storage Used")) {
                if let report {
                    LabeledContent(
                        String(localized: "settings.storage.volumes.label",
                               defaultValue: "Volume XML Files"),
                        value: formattedBytes(report.totalVolumesBytes)
                    )
                    LabeledContent(
                        String(localized: "settings.storage.index.label",
                               defaultValue: "Search Index"),
                        value: formattedBytes(report.totalIndexBytes)
                    )
                    LabeledContent(
                        String(localized: "settings.storage.summaries.label",
                               defaultValue: "AI Summaries"),
                        value: formattedBytes(report.totalSummariesBytes)
                    )
                    LabeledContent(
                        String(localized: "settings.storage.total.label",
                               defaultValue: "Grand Total"),
                        value: formattedBytes(report.grandTotalBytes)
                    )
                    .bold()
                } else if let error = loadError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.callout)
                } else {
                    ProgressView()
                }
            }

            if let report, !report.perVolume.isEmpty {
                Section(String(localized: "settings.storage.perVolume.header",
                               defaultValue: "Per-Volume Storage")) {
                    ForEach(report.perVolume, id: \.volumeId) { entry in
                        perVolumeRow(entry: entry)
                    }
                }
            }

            Section {
                Text(String(localized: "settings.storage.backup.note",
                            defaultValue: "Downloaded volume XML files are excluded from iCloud Backup to avoid redundant uploads. Files are re-downloadable at any time."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(String(localized: "settings.storage.title",
                                defaultValue: "Storage"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .frame(maxWidth: .infinity)
        .scrollIndicators(.visible)
        #endif
        .task {
            do {
                report = try await appState.downloadManager?.storageReport(indexDirectory: appState.indexDirectory)
            } catch {
                loadError = error.localizedDescription
            }
            // Load indexed status for all downloaded volumes after report is available.
            if let rep = report, let pipeline = appState.indexingPipeline {
                for perVol in rep.perVolume {
                    indexedStatus[perVol.volumeId] =
                        (try? pipeline.isVolumeIndexed(perVol.volumeId)) ?? false
                }
            }
        }
    }

    // MARK: - Per-Volume Row

    @ViewBuilder
    private func perVolumeRow(entry: VolumeStorageEntry) -> some View {
        let manifestEntry = appState.manifestStore.diffResult?.known
            .first { $0.volumeId == entry.volumeId }
            ?? appState.manifestStore.bundledEntries
            .first { $0.volumeId == entry.volumeId }

        // Two-line layout keeps each row within a narrow detail column.
        // Row 1: title (truncated) + file size right-aligned.
        // Row 2: volumeId + indexed-status / reindex control right-aligned.
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(manifestEntry?.title ?? entry.volumeId)
                    .font(.callout)
                    .lineLimit(2)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                Text(formattedBytes(entry.volumeFileBytes))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .fixedSize()    // prevent size label from wrapping
            }

            HStack(alignment: .center, spacing: 6) {
                Text(entry.volumeId)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let errMsg = reindexErrors[entry.volumeId] {
                    Text("· \(errMsg)")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if appState.indexingPipeline != nil {
                    indexedStatusView(volumeId: entry.volumeId)
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func indexedStatusView(volumeId: String) -> some View {
        if reindexingVolumeId == volumeId {
            // In-progress spinner
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.mini)
                Text(String(localized: "settings.storage.indexing",
                            defaultValue: "Indexing…"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if let isIndexed = indexedStatus[volumeId] {
            if isIndexed {
                Label(String(localized: "settings.storage.indexed",
                             defaultValue: "Indexed"),
                      systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .accessibilityLabel(
                        String(localized: "settings.storage.indexed.a11y",
                               defaultValue: "Volume is indexed for search"))
            } else {
                HStack(spacing: 6) {
                    Label(String(localized: "settings.storage.notIndexed",
                                 defaultValue: "Not Indexed"),
                          systemImage: "xmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button(String(localized: "settings.storage.reindex.button",
                                  defaultValue: "Reindex")) {
                        Task { await reindexVolume(volumeId) }
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                    .accessibilityLabel(
                        String(localized: "settings.storage.reindex.a11y",
                               defaultValue: "Reindex \(volumeId) for search"))
                }
            }
        }
        // nil means status not yet loaded; show nothing to avoid layout jitter
    }

    // MARK: - Reindex

    private func reindexVolume(_ volumeId: String) async {
        guard let pipeline = appState.indexingPipeline else { return }
        reindexingVolumeId = volumeId
        reindexErrors.removeValue(forKey: volumeId)
        do {
            try await pipeline.indexVolume(volumeId)
            indexedStatus[volumeId] = true
            #if DEBUG
            print("[Settings] Reindexed volume: \(volumeId)")
            #endif
        } catch {
            reindexErrors[volumeId] = error.localizedDescription
            #if DEBUG
            print("[Settings] Reindex failed for \(volumeId): \(error)")
            #endif
        }
        if reindexingVolumeId == volumeId { reindexingVolumeId = nil }
    }
}

// MARK: - SideloadError

/// Errors from `SideloadValidator`.
///
/// Version history:
///   1.0 — Session 24: initial implementation
enum SideloadError: LocalizedError {
    case notXML
    case notFRUSVolume(reason: String)
    case duplicateVolume(volumeId: String)
    case copyFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .notXML:
            return String(localized: "sideload.error.notXML",
                          defaultValue: "The selected file is not valid XML.")
        case .notFRUSVolume(let reason):
            return String(localized: "sideload.error.notFRUS",
                          defaultValue: "This XML file does not appear to be a FRUS volume: \(reason)")
        case .duplicateVolume(let id):
            return String(localized: "sideload.error.duplicate",
                          defaultValue: "Volume '\(id)' is already present. Delete it first to replace it.")
        case .copyFailed(let error):
            return String(localized: "sideload.error.copy",
                          defaultValue: "Could not import the file: \(error.localizedDescription)")
        }
    }
}

// MARK: - SideloadValidator

/// Validates and imports a sideloaded FRUS volume XML file.
///
/// Validation checks:
/// 1. File is parseable as XML.
/// 2. Root element looks like a FRUS TEI volume (root named `volume` or `TEI`/`tei`,
///    or has a `volumeId` / `xml:id` attribute).
/// 3. VolumeId (derived from filename) does not already exist on disk.
///
/// Version history:
///   1.0 — Session 24: initial implementation
struct SideloadValidator {

    /// Validates the file at `url` and imports it to `volumesDirectory` if valid.
    ///
    /// - Returns: The `volumeId` of the imported volume.
    /// - Throws: `SideloadError` describing the failure.
    func validate(url: URL, volumesDirectory: URL) throws -> String {
        let volumeId = url.deletingPathExtension().lastPathComponent

        // 1. Check root element via a quick XML parse
        guard let xmlParser = XMLParser(contentsOf: url) else {
            throw SideloadError.notXML
        }
        let rootDelegate = RootElementSnifferDelegate()
        xmlParser.delegate = rootDelegate
        xmlParser.parse()

        // An XML parse error (before finding root) means invalid XML
        if !rootDelegate.rootElementFound, xmlParser.parserError != nil {
            throw SideloadError.notXML
        }

        guard rootDelegate.rootElementFound else {
            throw SideloadError.notFRUSVolume(reason: String(
                localized: "sideload.error.noRoot", defaultValue: "No root element found."))
        }

        guard rootDelegate.looksLikeFRUS else {
            let reason = String(
                localized: "sideload.error.unexpectedRoot",
                defaultValue: "Unexpected root element '\(rootDelegate.rootElementName ?? "unknown")'.")
            throw SideloadError.notFRUSVolume(reason: reason)
        }

        // 2. Check for duplicate
        let dest = volumesDirectory.appendingPathComponent("\(volumeId).xml")
        if FileManager.default.fileExists(atPath: dest.path) {
            throw SideloadError.duplicateVolume(volumeId: volumeId)
        }

        // 3. Copy file to volumes directory
        do {
            try FileManager.default.createDirectory(
                at: volumesDirectory, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: url, to: dest)
        } catch {
            throw SideloadError.copyFailed(underlying: error)
        }

        #if DEBUG
        print("[Settings] Sideloaded volume: \(volumeId)")
        #endif

        return volumeId
    }
}

// MARK: - RootElementSnifferDelegate (internal for testing)

final class RootElementSnifferDelegate: NSObject, XMLParserDelegate {
    var rootElementFound = false
    var looksLikeFRUS = false
    var rootElementName: String? = nil
    private var hasFoundRoot = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes: [String: String] = [:]
    ) {
        guard !hasFoundRoot else { return }
        hasFoundRoot = true
        rootElementFound = true
        rootElementName = elementName

        let lower = elementName.lowercased()
        let knownRoots: Set<String> = ["volume", "tei", "tei:tei"]
        let hasFRUSAttribute = attributes.keys.contains("volumeId")
            || attributes.keys.contains("xml:id")
            || (attributes["xmlns"] ?? "").contains("frus")

        looksLikeFRUS = knownRoots.contains(lower) || hasFRUSAttribute

        // Stop parsing — we have what we need
        parser.abortParsing()
    }
}

// MARK: - SideloadView

private struct SideloadView: View {

    @Environment(AppState.self) private var appState

    @State private var isImporting = false
    @State private var importResult: ImportResult? = nil

    enum ImportResult {
        case success(volumeId: String)
        case failure(String)
    }

    var body: some View {
        Form {
            Section(String(localized: "settings.sideload.about.header",
                           defaultValue: "About Sideloading")) {
                Text(String(localized: "settings.sideload.about.body",
                            defaultValue: "Import a FRUS volume XML file from your device. The file will be validated and added to your library. Standard FRUS volumes are available for download from the Volume Management screen."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    isImporting = true
                } label: {
                    Label(
                        String(localized: "settings.sideload.import.button",
                               defaultValue: "Choose XML File…"),
                        systemImage: "doc.badge.plus"
                    )
                }
                .accessibilityLabel(
                    String(localized: "settings.sideload.import.a11y",
                           defaultValue: "Choose a FRUS volume XML file to import")
                )
            }

            if let result = importResult {
                Section {
                    switch result {
                    case .success(let volumeId):
                        Label(
                            String(localized: "settings.sideload.success",
                                   defaultValue: "Imported '\(volumeId)' successfully."),
                            systemImage: "checkmark.circle"
                        )
                        .foregroundStyle(.green)
                        .font(.callout)
                    case .failure(let message):
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "settings.sideload.title",
                                defaultValue: "Sideload Volume"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .frame(maxWidth: .infinity)
        .scrollIndicators(.visible)
        #endif
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.xml],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importResult = .failure(error.localizedDescription)
        case .success(let urls):
            guard let url = urls.first else { return }
            guard let dm = appState.downloadManager else {
                importResult = .failure(
                    String(localized: "settings.sideload.error.noManager",
                           defaultValue: "Download manager not available."))
                return
            }
            let validator = SideloadValidator()
            do {
                let volumeId = try validator.validate(
                    url: url, volumesDirectory: dm.volumesDirectory)
                importResult = .success(volumeId: volumeId)
                // Trigger reindex of the newly sideloaded volume
                if let pipeline = appState.indexingPipeline {
                    Task {
                        let volumeURL = dm.volumeURL(for: volumeId)
                        try? await pipeline.indexVolume(volumeId)
                        _ = volumeURL
                    }
                }
            } catch {
                importResult = .failure(error.localizedDescription)
            }
        }
    }
}

// MARK: - ReindexView

private struct ReindexView: View {

    @Environment(AppState.self) private var appState

    @State private var isReindexing = false
    @State private var progressState: IndexingProgress.State = .idle
    @State private var reindexError: String? = nil
    @State private var reindexingInterruptedId: String? = nil

    var body: some View {
        Form {
            // "Needs Attention" section: volumes whose prior indexing pass was interrupted.
            let interrupted = Array(appState.interruptedVolumeIds).sorted()
            if !interrupted.isEmpty {
                Section(String(localized: "settings.reindex.interrupted.header",
                               defaultValue: "Needs Attention")) {
                    Text(String(localized: "settings.reindex.interrupted.body",
                                defaultValue: "These volumes were being indexed when the app was last quit. Re-index them to restore full search coverage."))
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    ForEach(interrupted, id: \.self) { volumeId in
                        let title = appState.manifestStore.entry(forVolumeId: volumeId)?.title ?? volumeId
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title)
                                    .font(.callout)
                                    .lineLimit(1)
                                Text(volumeId)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(String(localized: "settings.reindex.interrupted.reindex",
                                          defaultValue: "Re-index")) {
                                reindexInterrupted(volumeId: volumeId)
                            }
                            .buttonStyle(.bordered)
                            .disabled(isReindexing || reindexingInterruptedId != nil
                                      || appState.indexingPipeline == nil)
                        }
                    }

                    Button {
                        startReindexAllInterrupted(interrupted)
                    } label: {
                        if reindexingInterruptedId == "all" {
                            HStack {
                                ProgressView().padding(.trailing, 4)
                                Text(progressLabel).font(.callout)
                            }
                        } else {
                            Label(
                                String(localized: "settings.reindex.interrupted.all",
                                       defaultValue: "Re-index All Interrupted"),
                                systemImage: "exclamationmark.triangle"
                            )
                        }
                    }
                    .disabled(isReindexing || reindexingInterruptedId != nil
                              || appState.indexingPipeline == nil)
                }
            }

            Section(String(localized: "settings.reindex.about.header",
                           defaultValue: "About Reindexing")) {
                Text(String(localized: "settings.reindex.about.body",
                            defaultValue: "Rebuilds the full-text search index from all downloaded volumes. Use this if search results are missing or incorrect."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    startReindex()
                } label: {
                    if isReindexing {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 4)
                            Text(progressLabel)
                                .font(.callout)
                        }
                    } else {
                        Label(
                            String(localized: "settings.reindex.start.button",
                                   defaultValue: "Reindex All Volumes"),
                            systemImage: "magnifyingglass.circle"
                        )
                    }
                }
                .disabled(isReindexing || reindexingInterruptedId != nil
                          || appState.indexingPipeline == nil)
                .accessibilityLabel(
                    String(localized: "settings.reindex.start.a11y",
                           defaultValue: "Reindex all downloaded FRUS volumes")
                )

                if case .completed(let volumes, let docs) = progressState {
                    Label(
                        String(localized: "settings.reindex.done",
                               defaultValue: "Completed: \(volumes) volume\(volumes == 1 ? "" : "s"), \(docs) documents"),
                        systemImage: "checkmark.circle"
                    )
                    .foregroundStyle(.green)
                    .font(.callout)
                }

                if let error = reindexError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .navigationTitle(String(localized: "settings.reindex.title", defaultValue: "Reindex"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .frame(maxWidth: .infinity)
        .scrollIndicators(.visible)
        #endif
    }

    private var progressLabel: String {
        switch progressState {
        case .idle:
            return String(localized: "settings.reindex.progress.starting",
                          defaultValue: "Starting…")
        case .indexing(let volumeId, let current, let total):
            return String(localized: "settings.reindex.progress.indexing",
                          defaultValue: "\(current)/\(total) — \(volumeId)")
        case .completed, .failed:
            return ""
        }
    }

    private func startReindex() {
        guard let pipeline = appState.indexingPipeline else { return }
        isReindexing = true
        progressState = .idle
        reindexError = nil

        Task {
            // Consume the progress stream while running reindex
            async let progressTask: Void = {
                for await event in pipeline.progress {
                    await MainActor.run { progressState = event.state }
                }
            }()
            do {
                try await pipeline.indexAllVolumes()
            } catch {
                await MainActor.run {
                    reindexError = error.localizedDescription
                    #if DEBUG
                    print("[Settings] Reindex failed: \(error)")
                    #endif
                }
            }
            _ = await progressTask
            await MainActor.run { isReindexing = false }
        }
    }

    private func reindexInterrupted(volumeId: String) {
        guard let pipeline = appState.indexingPipeline else { return }
        reindexingInterruptedId = volumeId
        reindexError = nil
        Task {
            do {
                try await pipeline.indexVolume(volumeId)
            } catch {
                await MainActor.run {
                    reindexError = error.localizedDescription
                }
            }
            await MainActor.run { reindexingInterruptedId = nil }
        }
    }

    private func startReindexAllInterrupted(_ volumeIds: [String]) {
        guard let pipeline = appState.indexingPipeline else { return }
        reindexingInterruptedId = "all"
        reindexError = nil
        Task {
            for volumeId in volumeIds {
                do {
                    try await pipeline.indexVolume(volumeId)
                } catch {
                    await MainActor.run {
                        reindexError = error.localizedDescription
                        #if DEBUG
                        print("[Settings] Re-index interrupted volume \(volumeId) failed: \(error)")
                        #endif
                    }
                }
            }
            await MainActor.run { reindexingInterruptedId = nil }
        }
    }
}

// MARK: - UserTagsView

private struct UserTagsView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserTag.name) private var tags: [UserTag]

    @State private var renamingTag: UserTag? = nil
    @State private var renameText = ""
    @State private var mergingTag: UserTag? = nil
    @State private var mergeTargetId: UUID? = nil

    var body: some View {
        Form {
            Section {
                if tags.isEmpty {
                    Text(String(localized: "settings.tags.empty",
                                defaultValue: "No user tags created yet."))
                        .foregroundStyle(.secondary)
                        .font(.callout)
                } else {
                    ForEach(tags) { tag in
                        let isRenaming = renamingTag?.id == tag.id
                        HStack {
                            if isRenaming {
                                TextField(
                                    String(localized: "settings.tags.rename.placeholder",
                                           defaultValue: "Tag name"),
                                    text: $renameText
                                )
                                .onSubmit { commitRename() }
                                .accessibilityLabel(
                                    String(localized: "settings.tags.rename.a11y",
                                           defaultValue: "Rename tag \(tag.name)")
                                )
                            } else {
                                Text(tag.name)
                            }
                            Spacer()
                            if !isRenaming {
                                Button(String(localized: "settings.tags.merge.button",
                                              defaultValue: "Merge…")) {
                                    mergingTag = tag
                                    mergeTargetId = nil
                                }
                                .font(.caption)
                                .buttonStyle(.borderless)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel(
                                    String(localized: "settings.tags.merge.a11y",
                                           defaultValue: "Merge tag \(tag.name) into another")
                                )
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard renamingTag == nil else { return }
                            renamingTag = tag
                            renameText = tag.name
                        }
                        // Leading swipe: Edit (rename). Makes the rename action discoverable
                        // for users who may not know about tap-to-rename.
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if !isRenaming {
                                Button {
                                    renamingTag = tag
                                    renameText = tag.name
                                } label: {
                                    Label(
                                        String(localized: "settings.tags.rename.swipe",
                                               defaultValue: "Rename"),
                                        systemImage: "pencil"
                                    )
                                }
                                .tint(.accentColor)
                                .accessibilityLabel(
                                    String(localized: "settings.tags.rename.swipe.a11y",
                                           defaultValue: "Rename tag \(tag.name)")
                                )
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            modelContext.delete(tags[index])
                        }
                    }
                }
            } header: {
                Text(String(localized: "settings.tags.list.header", defaultValue: "Tags"))
            } footer: {
                Text(String(localized: "settings.tags.list.footer",
                            defaultValue: "Tap or swipe right to rename. Swipe left to delete."))
                    .font(.caption)
            }
        }
        .navigationTitle(String(localized: "settings.tags.title", defaultValue: "User Tags"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .frame(maxWidth: .infinity)
        .scrollIndicators(.visible)
        #endif
        .toolbar {
            if renamingTag != nil {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "settings.tags.rename.done", defaultValue: "Done")) {
                        commitRename()
                    }
                }
            }
        }
        .sheet(item: $mergingTag) { sourceTag in
            MergeTagSheet(
                sourceTag: sourceTag,
                allTags: tags.filter { $0.id != sourceTag.id },
                onMerge: { targetTag in
                    mergeTag(source: sourceTag, into: targetTag)
                    mergingTag = nil
                }
            )
        }
    }

    private func commitRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let tag = renamingTag {
            tag.name = trimmed
        }
        renamingTag = nil
        renameText = ""
    }

    private func mergeTag(source: UserTag, into target: UserTag) {
        // Update all notes that reference the source tag to reference the target tag instead
        let sourceId = source.id
        let targetId = target.id
        var descriptor = FetchDescriptor<ResearchNote>(
            predicate: #Predicate { note in note.userTagIds.contains(sourceId) }
        )
        descriptor.fetchLimit = 500
        let affected = (try? modelContext.fetch(descriptor)) ?? []
        for note in affected {
            var ids = note.userTagIds.filter { $0 != sourceId }
            if !ids.contains(targetId) { ids.append(targetId) }
            note.userTagIds = ids
        }
        modelContext.delete(source)

        #if DEBUG
        print("[Settings] Merged tag \(source.name) into \(target.name); updated \(affected.count) notes")
        #endif
    }
}

// MARK: - MergeTagSheet

private struct MergeTagSheet: View {
    let sourceTag: UserTag
    let allTags: [UserTag]
    let onMerge: (UserTag) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTagId: UUID? = nil

    @ViewBuilder
    private func mergeTagRow(tag: UserTag) -> some View {
        let isSelected: Bool = selectedTagId == tag.id
        HStack {
            Text(tag.name)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedTagId = tag.id }
        .accessibilityLabel(tag.name)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "settings.tags.merge.source.header",
                               defaultValue: "Merge '\(sourceTag.name)' into:")) {
                    ForEach(allTags) { tag in
                        mergeTagRow(tag: tag)
                    }
                }

                Text(String(localized: "settings.tags.merge.explanation",
                            defaultValue: "All notes tagged '\(sourceTag.name)' will be re-tagged with the selected tag. '\(sourceTag.name)' will be deleted."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle(String(localized: "settings.tags.merge.title",
                                    defaultValue: "Merge Tag"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "settings.tags.merge.cancel",
                                  defaultValue: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "settings.tags.merge.confirm",
                                  defaultValue: "Merge")) {
                        if let id = selectedTagId,
                           let target = allTags.first(where: { $0.id == id }) {
                            onMerge(target)
                        }
                    }
                    .disabled(selectedTagId == nil)
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 260)
        #endif
    }
}

// MARK: - SummarizationPromptsSettingsView

private struct SummarizationPromptsSettingsView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SummarizationPrompt.createdAt) private var allPrompts: [SummarizationPrompt]
    @Query(sort: \GeneratedSummary.lastModified, order: .reverse) private var allSummaries: [GeneratedSummary]

    /// Non-nil when editing an existing user prompt.
    @State private var editingPrompt: SummarizationPrompt? = nil
    /// Controls the new-prompt creation sheet.
    @State private var showNewPromptSheet: Bool = false
    /// When set, the new-prompt sheet opens pre-populated from this template
    /// (used by "Use as Template" on standard prompts and "Duplicate" on user prompts).
    @State private var newPromptInitialTemplate: PromptTemplate? = nil

    var body: some View {
        Form {
            promptsSection
            summaryCountsSection
            backgroundSection
        }
        .navigationTitle(String(localized: "settings.summarization.title",
                                defaultValue: "Summarization Prompts"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .frame(maxWidth: .infinity)
        .scrollIndicators(.visible)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newPromptInitialTemplate = nil
                    showNewPromptSheet = true
                } label: {
                    Label(String(localized: "settings.summarization.newPrompt.button",
                                 defaultValue: "New Prompt"),
                          systemImage: "plus")
                }
                .accessibilityLabel(
                    String(localized: "settings.summarization.newPrompt.a11y",
                           defaultValue: "Create a new summarization prompt")
                )
            }
        }
        // Sheet for editing an existing user prompt
        .sheet(item: $editingPrompt) { prompt in
            PromptEditorView(promptToEdit: prompt)
        }
        // Sheet for creating a new prompt (optionally pre-seeded from a template)
        .sheet(isPresented: $showNewPromptSheet, onDismiss: { newPromptInitialTemplate = nil }) {
            PromptEditorView(initialTemplate: newPromptInitialTemplate)
        }
    }

    @ViewBuilder
    private var promptsSection: some View {
        let standard = allPrompts.filter { $0.isStandard }
        let user = allPrompts.filter { !$0.isStandard }

        if !standard.isEmpty {
            Section(String(localized: "settings.summarization.standard.header",
                           defaultValue: "Standard Prompts")) {
                ForEach(standard) { prompt in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(prompt.name).font(.callout)
                            Text(summaryCountLabel(for: prompt))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            newPromptInitialTemplate = templateFrom(prompt)
                            showNewPromptSheet = true
                        } label: {
                            Text(String(localized: "settings.summarization.useAsTemplate",
                                        defaultValue: "Use as Template"))
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityLabel(
                            String(localized: "settings.summarization.useAsTemplate.a11y",
                                   defaultValue: "Use \(prompt.name) as a template for a new prompt")
                        )
                    }
                }
            }
        }

        Section(String(localized: "settings.summarization.user.header",
                       defaultValue: "Your Prompts")) {
            if user.isEmpty {
                Text(String(localized: "settings.summarization.user.empty",
                            defaultValue: "No custom prompts yet. Tap + to create one."))
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(user) { prompt in
                    Button {
                        editingPrompt = prompt
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(prompt.name)
                                    .font(.callout)
                                    .foregroundStyle(.primary)
                                Text(summaryCountLabel(for: prompt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel(
                        String(localized: "settings.summarization.prompt.a11y",
                               defaultValue: "Edit prompt \(prompt.name)")
                    )
                    // Leading swipe: Duplicate (creates new prompt pre-seeded from this one)
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            newPromptInitialTemplate = templateFrom(prompt)
                            showNewPromptSheet = true
                        } label: {
                            Label(String(localized: "settings.summarization.duplicate",
                                         defaultValue: "Duplicate"),
                                  systemImage: "doc.on.doc")
                        }
                        .tint(.accentColor)
                    }
                }
                .onDelete { offsets in
                    for i in offsets { modelContext.delete(user[i]) }
                }
            }
        }
    }

    /// Builds a `PromptTemplate` value from any `SummarizationPrompt` for use-as-template flows.
    private func templateFrom(_ prompt: SummarizationPrompt) -> PromptTemplate {
        let fields: [StructuredSummarySchema.Field]
        if case .structured(let schema) = prompt.responseFormat {
            fields = schema.fields
        } else {
            fields = []
        }
        return PromptTemplate(
            id: UUID(),
            name: String(localized: "settings.summarization.copyOf",
                         defaultValue: "Copy of \(prompt.name)"),
            promptText: prompt.promptText,
            fields: fields
        )
    }

    @ViewBuilder
    private var summaryCountsSection: some View {
        Section(String(localized: "settings.summarization.counts.header",
                       defaultValue: "Summaries")) {
            LabeledContent(
                String(localized: "settings.summarization.counts.total", defaultValue: "Total Summaries"),
                value: "\(allSummaries.count)"
            )
        }
    }

    @ViewBuilder
    private var backgroundSection: some View {
        Section(String(localized: "settings.summarization.background.header",
                       defaultValue: "Background Summarization")) {
            BackgroundSummarizationSettingsView()
        }
    }

    private func summaryCountLabel(for prompt: SummarizationPrompt) -> String {
        let count = allSummaries.filter { $0.promptId == prompt.id }.count
        return String(localized: "settings.summarization.prompt.count",
                      defaultValue: "\(count) summary\(count == 1 ? "" : "ies") generated")
    }
}

// MARK: - NARAKeyView

private struct NARAKeyView: View {

    @State private var keyText: String = ""
    @State private var hasExistingKey: Bool = false
    @State private var isSaving: Bool = false
    @State private var saveResult: SaveResult? = nil

    private let keychainStore = KeychainStore.shared

    enum SaveResult {
        case saved, cleared, error(String)
    }

    var body: some View {
        Form {
            Section(String(localized: "settings.naraKey.about.header",
                           defaultValue: "About the NARA Catalog API Key")) {
                Text(String(localized: "settings.naraKey.about.body",
                            defaultValue: "A free API key from the National Archives Catalog is required to search for lot file and Presidential Library records in the Source Explorer. The key is stored securely in iCloud Keychain and synced across your devices."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section(String(localized: "settings.naraKey.entry.header",
                           defaultValue: "API Key")) {
                if hasExistingKey && keyText.isEmpty {
                    Text(String(localized: "settings.naraKey.stored",
                                defaultValue: "A key is currently stored."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                SecureField(
                    String(localized: "settings.naraKey.field.placeholder",
                           defaultValue: hasExistingKey ? "Enter new key to replace…" : "Paste your API key here…"),
                    text: $keyText
                )
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.asciiCapable)
                #endif
                .accessibilityLabel(
                    String(localized: "settings.naraKey.field.a11y",
                           defaultValue: "NARA Catalog API key field")
                )

                HStack {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text(String(localized: "settings.naraKey.save.button",
                                        defaultValue: "Save Key"))
                        }
                    }
                    .disabled(keyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                    .accessibilityLabel(
                        String(localized: "settings.naraKey.save.a11y", defaultValue: "Save API key")
                    )

                    if hasExistingKey {
                        Spacer()
                        Button(String(localized: "settings.naraKey.clear.button",
                                      defaultValue: "Clear Key"), role: .destructive) {
                            clearKey()
                        }
                        .accessibilityLabel(
                            String(localized: "settings.naraKey.clear.a11y",
                                   defaultValue: "Remove stored API key")
                        )
                    }
                }
            }

            if let result = saveResult {
                Section {
                    switch result {
                    case .saved:
                        Label(
                            String(localized: "settings.naraKey.saved",
                                   defaultValue: "API key saved."),
                            systemImage: "checkmark.circle"
                        )
                        .foregroundStyle(.green)
                        .font(.callout)
                    case .cleared:
                        Label(
                            String(localized: "settings.naraKey.cleared",
                                   defaultValue: "API key removed."),
                            systemImage: "trash"
                        )
                        .font(.callout)
                    case .error(let msg):
                        Label(msg, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "settings.naraKey.title",
                                defaultValue: "NARA Catalog API Key"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .frame(maxWidth: .infinity)
        .scrollIndicators(.visible)
        #endif
        .task {
            hasExistingKey = await keychainStore.hasAPIKey()
        }
    }

    private func save() {
        let trimmed = keyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        saveResult = nil
        Task {
            do {
                try await keychainStore.setNARACatalogAPIKey(trimmed)
                keyText = ""
                hasExistingKey = true
                saveResult = .saved
                #if DEBUG
                print("[Settings] NARA API key saved")
                #endif
            } catch {
                saveResult = .error(error.localizedDescription)
            }
            isSaving = false
        }
    }

    private func clearKey() {
        Task {
            do {
                try await keychainStore.deleteNARACatalogAPIKey()
                keyText = ""
                hasExistingKey = false
                saveResult = .cleared
                #if DEBUG
                print("[Settings] NARA API key cleared")
                #endif
            } catch {
                saveResult = .error(error.localizedDescription)
            }
        }
    }
}

// MARK: - ResetView

/// Two-step confirmation UI for the destructive "Reset App to Initial State" action.
///
/// ## What is deleted
/// - All downloaded volume XML files (via `DownloadManager`)
/// - All SwiftData user-generated records: `ResearchNote`, `UserTag`, `GeneratedSummary`,
///   `ReadingHistoryEntry`, `Collection`, `CollectionEntry`, `SummarizationPrompt`, `Project`
/// - Active project selection (`AppState.activeProjectId`)
///
/// ## Post-reset navigation
/// Both platforms now set `hasCompletedOnboarding = false` directly after clearing data.
/// - **iOS**: Settings is a persistent tab — no sheet is on screen.
/// - **macOS**: Settings is now a `Settings` scene (independent window, not a modal sheet).
///   There is no animation race with `ContentView`, so direct assignment is safe.
///
/// ## Confirmation gates
/// The user must confirm twice (two `confirmationDialog` calls) before `performReset()`
/// is invoked, guarding against accidental taps.
///
/// Version history:
///   1.0 — Session 24: initial implementation
///   1.1 — Session 32: added `Project` deletion; switched to two-phase sheet-dismissal
///          for safe post-reset onboarding navigation (macOS)
///   1.2 — Session 44: iOS path simplified to direct assignment
///   1.3 — Session 46: macOS path also simplified; pendingOnboardingAfterReset removed
private struct ResetView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var showFirstConfirmation = false
    @State private var showSecondConfirmation = false
    @State private var isResetting = false
    @State private var resetError: String? = nil

    var body: some View {
        Form {
            Section {
                Text(String(localized: "settings.reset.warning",
                            defaultValue: "This will delete all downloaded volumes, your search index, all research notes, projects, user tags, collections, and AI-generated summaries. This action cannot be undone."))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Button(String(localized: "settings.reset.button",
                              defaultValue: "Reset App to Initial State"), role: .destructive) {
                    showFirstConfirmation = true
                }
                .disabled(isResetting)
                .accessibilityLabel(
                    String(localized: "settings.reset.button.a11y",
                           defaultValue: "Reset app to initial state. Destructive action.")
                )
            }

            if let error = resetError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .navigationTitle(String(localized: "settings.reset.title", defaultValue: "Reset App"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .frame(maxWidth: .infinity)
        .scrollIndicators(.visible)
        #endif
        .confirmationDialog(
            String(localized: "settings.reset.confirm1.title",
                   defaultValue: "Reset FRUS Explorer?"),
            isPresented: $showFirstConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.reset.confirm1.proceed",
                          defaultValue: "Continue"), role: .destructive) {
                showSecondConfirmation = true
            }
            Button(String(localized: "settings.reset.cancel",
                          defaultValue: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "settings.reset.confirm1.message",
                        defaultValue: "All user data will be permanently deleted. Are you sure?"))
        }
        .confirmationDialog(
            String(localized: "settings.reset.confirm2.title",
                   defaultValue: "This Cannot Be Undone"),
            isPresented: $showSecondConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.reset.confirm2.proceed",
                          defaultValue: "Delete Everything"), role: .destructive) {
                performReset()
            }
            Button(String(localized: "settings.reset.cancel",
                          defaultValue: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "settings.reset.confirm2.message",
                        defaultValue: "All downloaded volumes, research notes, projects, and summaries will be deleted immediately."))
        }
    }

    private func performReset() {
        isResetting = true
        resetError = nil
        Task {
            do {
                // Delete all downloaded .xml files directly from the filesystem.
                // Iterating manifest entries misses files not currently in the manifest,
                // which would leave hasDownloadedVolumes() returning true and block OnboardingView.
                if let dm = appState.downloadManager {
                    let dir = dm.volumesDirectory
                    if let files = try? FileManager.default.contentsOfDirectory(
                        at: dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
                    ) {
                        for file in files where file.pathExtension.lowercased() == "xml" {
                            try? FileManager.default.removeItem(at: file)
                        }
                    }
                }
                // Clear the search index so re-indexing after onboarding starts from scratch.
                if let pipeline = appState.indexingPipeline {
                    try await pipeline.removeAllVolumesFromIndex()
                    await MainActor.run { appState.indexGeneration += 1 }
                }
                // Delete all SwiftData user-generated records
                try modelContext.delete(model: ResearchNote.self)
                try modelContext.delete(model: UserTag.self)
                try modelContext.delete(model: GeneratedSummary.self)
                try modelContext.delete(model: ReadingHistoryEntry.self)
                try modelContext.delete(model: Collection.self)
                try modelContext.delete(model: CollectionEntry.self)
                try modelContext.delete(model: SummarizationPrompt.self)
                try modelContext.delete(model: Project.self)
                await MainActor.run {
                    appState.activeProjectId = nil
                    // Both iOS and macOS now use direct assignment. On iOS, Settings is
                    // a persistent tab; on macOS, Settings is a Settings scene (independent
                    // window). Neither path has a modal sheet on screen that could race
                    // with ContentView's transition to OnboardingView.
                    appState.hasCompletedOnboarding = false
                }

                #if DEBUG
                print("[Settings] App reset complete")
                #endif
            } catch {
                await MainActor.run {
                    resetError = error.localizedDescription
                    isResetting = false
                }
                return
            }
            await MainActor.run { isResetting = false }
        }
    }
}

// MARK: - DisplaySettingsView

private struct DisplaySettingsView: View {
    @AppStorage("frus.display.textSize") private var textSize: TextSizePreference = .medium
    @AppStorage("frus.display.showDocumentNumbers") private var showDocumentNumbers = true

    var body: some View {
        Form {
            Section {
                Picker(String(localized: "settings.display.textSize.label",
                              defaultValue: "Document Text Size"),
                       selection: $textSize) {
                    ForEach(TextSizePreference.allCases) { size in
                        Text(size.label).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel(
                    String(localized: "settings.display.textSize.a11y",
                           defaultValue: "Document text size")
                )
            } header: {
                Text(String(localized: "settings.display.textSize.header",
                            defaultValue: "Text Size"))
            } footer: {
                Text(String(localized: "settings.display.textSize.footer",
                            defaultValue: "Adjusts the body text size in the Document view."))
            }

            Section {
                Toggle(String(localized: "settings.display.showNumbers.label",
                              defaultValue: "Show Document Numbers"),
                       isOn: $showDocumentNumbers)
                .accessibilityLabel(
                    String(localized: "settings.display.showNumbers.a11y",
                           defaultValue: "Show document numbers in the document view")
                )
            } header: {
                Text(String(localized: "settings.display.documentView.header",
                            defaultValue: "Document View"))
            } footer: {
                Text(String(localized: "settings.display.showNumbers.footer",
                            defaultValue: "Displays the printed document number (e.g. \"Document 28\") in the document identity line."))
            }
        }
        .navigationTitle(String(localized: "settings.display.title", defaultValue: "Display"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .frame(maxWidth: .infinity)
        .scrollIndicators(.visible)
        #endif
    }
}

// MARK: - SearchDefaultsView

private struct SearchDefaultsView: View {
    @AppStorage("frus.search.scopeDocuments")    private var scopeDocuments    = true
    @AppStorage("frus.search.scopeNotes")        private var scopeNotes        = true
    @AppStorage("frus.search.scopeSummaries")    private var scopeSummaries    = true
    @AppStorage("frus.search.defaultTypeFilter") private var defaultTypeFilter = "all"

    var body: some View {
        Form {
            Section(header: Text(String(localized: "settings.search.scope.header",
                                        defaultValue: "Default Search Scope")),
                    footer: Text(String(localized: "settings.search.scope.footer",
                                        defaultValue: "These defaults can be overridden per-session in the Search filter panel."))) {
                Toggle(String(localized: "settings.search.scope.documents",
                              defaultValue: "Documents"),
                       isOn: $scopeDocuments)
                .accessibilityLabel(
                    String(localized: "settings.search.scope.documents.a11y",
                           defaultValue: "Search FRUS document text by default")
                )
                Toggle(String(localized: "settings.search.scope.notes",
                              defaultValue: "Research Notes"),
                       isOn: $scopeNotes)
                .accessibilityLabel(
                    String(localized: "settings.search.scope.notes.a11y",
                           defaultValue: "Include research notes in search results by default")
                )
                Toggle(String(localized: "settings.search.scope.summaries",
                              defaultValue: "AI Summaries"),
                       isOn: $scopeSummaries)
                .accessibilityLabel(
                    String(localized: "settings.search.scope.summaries.a11y",
                           defaultValue: "Include AI summaries in search results by default")
                )
            }

            Section(String(localized: "settings.search.typeFilter.header",
                           defaultValue: "Default Document Type")) {
                Picker(String(localized: "settings.search.typeFilter.label",
                              defaultValue: "Default type filter"),
                       selection: $defaultTypeFilter) {
                    Text(String(localized: "settings.search.typeFilter.all",
                                defaultValue: "Both")).tag("all")
                    Text(String(localized: "settings.search.typeFilter.docs",
                                defaultValue: "Primary Documents Only")).tag("documentsOnly")
                    Text(String(localized: "settings.search.typeFilter.editorialNotes",
                                defaultValue: "Editorial Notes Only")).tag("editorialNotesOnly")
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .accessibilityLabel(
                    String(localized: "settings.search.typeFilter.a11y",
                           defaultValue: "Default document type filter")
                )
            }
        }
        .navigationTitle(String(localized: "settings.search.title",
                                defaultValue: "Search Defaults"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .frame(maxWidth: .infinity)
        .scrollIndicators(.visible)
        #endif
    }
}

// MARK: - Shared Helpers

/// Formats a byte count using `ByteCountFormatter` with adaptive style.
func formattedBytes(_ bytes: Int) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(bytes))
}

// MARK: - SettingsKeys

enum SettingsKeys {
    static let concurrentDownloadLimit = "frus.concurrentDownloadLimit"
}

