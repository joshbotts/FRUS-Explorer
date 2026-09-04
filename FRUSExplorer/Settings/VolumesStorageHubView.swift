// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(iOS)

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - VolumesStorageHubView

/// The iOS **Volumes & Storage** destination — the twin of `MacVolumesStorageHub` (S-2c).
///
/// ## What this replaces
/// Three separate Settings rows: `DownloadsSettingsView` ("Add Volumes"), `StorageManagementView`
/// ("Storage & Index"), and `SideloadView` ("Sideload Volume"). Between them they split one job —
/// get the corpus onto this device and keep it searchable — across three screens, so answering
/// "have I got enough room for another subseries?" meant visiting two of them and doing the
/// arithmetic yourself.
///
/// ## Same grammar as the Mac
/// Section order, copy, and behaviour match `MacVolumesStorageHub` deliberately: hero → Add
/// Volumes → Downloaded Volumes → Needs Attention → Keeping Current → Storage & Index → Advanced.
/// Where the platforms differ, they differ for a reason and the reason is stated:
///
/// - **Pushes, not sheets.** The full volume list and the GitHub browser are `NavigationLink`
///   destinations here; on macOS they are sheets, because a Settings window carries no navigation
///   chrome of its own.
/// - **Extra rows iOS earns.** Active Downloads (with per-transfer cancel), Allow Cellular
///   Downloads, and the indexing Live Activity toggle have no Mac equivalent and stay.
///
/// ## Live-query hazard (do not "improve" this)
/// `protectedVolumeIds` and `lastOpenedByVolumeId` are one-shot fetches refreshed by
/// `loadReport()`, deliberately **not** `@Query`. A `@Query` re-renders the whole pane on every
/// change to its model type, so CloudKit drip-importing notes/summaries/collections/history rows
/// re-rendered it continuously; left open overnight that pegged a CPU core (Session 160).
/// `indexedVolumeIds` snapshots on the same cadence, replacing the old per-row `indexedStatus`
/// dictionary.
///
/// Version history:
///   1.0 — S-2c: initial implementation, merging `DownloadsSettingsView` +
///          `StorageManagementView` + `SideloadView`
struct VolumesStorageHubView: View {

    // MARK: - Batch tracking

    /// Tracks the kind and progress of a Settings-triggered bulk indexing run.
    ///
    /// The old Storage pane had a third mode, "Reindex All Volumes" — `indexAllVolumes()` with no
    /// prior wipe. The hub drops it on both platforms per the settled design: "Rebuild From
    /// Scratch" does everything it did and also clears rows orphaned by deleted volumes and FTS5
    /// fragmentation, which is the actual reason anyone reached for a full re-index.
    private enum BatchKind {
        /// Iterating through unindexed volumes one by one; `current` is 1-based.
        case indexRemaining(current: Int, total: Int)
        /// Running `removeAllVolumesFromIndex()` followed by `indexAllVolumes()`.
        case rebuildAll(total: Int)
    }

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    // MARK: - Snapshot state (see the live-query hazard note above)

    /// Volumes carrying notes, collections, or summaries — never offered for removal.
    @State private var protectedVolumeIds: Set<String> = []
    /// Most recent reading-history timestamp per volume, for the removal ordering.
    @State private var lastOpenedByVolumeId: [String: Date] = [:]
    /// Volumes present in the search index, snapshotted with the storage report.
    @State private var indexedVolumeIds: Set<String> = []
    /// The storage measurement; `nil` until the first `loadReport()` completes.
    @State private var storageReport: StorageReport? = nil
    /// Message from a failed storage measurement.
    @State private var loadError: String? = nil
    /// The live-versus-reclaimable split of the index file, refreshed with the storage report.
    @State private var indexPages: IndexPageStatistics? = nil
    /// Free space on the volume holding the index, for the compaction precondition.
    @State private var availableBytes: Int? = nil
    /// Set while VACUUM holds its exclusive write lock.
    @State private var isCompacting = false
    /// What the last compaction reclaimed, so the row can confirm it did something.
    @State private var compactedBytes: Int? = nil


    // MARK: - Indexing state

    /// Volume being re-indexed from the full list; drives that row's spinner.
    @State private var reindexingVolumeId: String? = nil
    /// Number of volumes that failed during the most recent indexing run.
    @State private var bulkIndexingFailureCount: Int? = nil
    /// Non-nil while a Settings-triggered bulk indexing batch is active.
    @State private var settingsBatch: BatchKind? = nil
    /// The interrupted volume currently being re-indexed, or `"all"` during the sweep.
    @State private var reindexingInterruptedId: String? = nil
    /// Controls the "Rebuild From Scratch" confirmation alert.
    @State private var showRebuildConfirmation = false

    // MARK: - Sheets

    /// Controls the Free Up Space sheet.
    @State private var showFreeUpSpaceSheet = false

    // MARK: - Sideload state

    @State private var isImporting = false
    /// Result of the most recent sideload, or `nil` before the first attempt.
    @State private var sideloadOutcome: SideloadOutcome? = nil

    // MARK: - Keeping Current state

    @State private var updatableVolumes: [UpdatableVolume] = []
    @State private var isCheckingForUpdates = false
    @State private var hasCheckedForUpdates = false
    @State private var isRefreshingCatalog = false

    // MARK: - Advanced state

    /// Seeded from UserDefaults so the picker reflects the active limit.
    @State private var concurrentDownloadLimit: Int = {
        let stored = UserDefaults.standard.integer(forKey: SettingsKeys.concurrentDownloadLimit)
        return stored > 0 ? stored : 4
    }()

    /// Whether volume downloads may run over cellular.
    @AppStorage(SettingsKeys.allowCellularDownloads) private var allowCellularDownloads: Bool = true
    /// Whether indexing progress shows a Live Activity / Dynamic Island widget.
    @AppStorage(SettingsKeys.liveActivityEnabled) private var liveActivityEnabled = true

    /// `true` while `rebuildSpotlightIndex()` is running.
    @State private var spotlightRebuildRunning = false
    /// `true` once a Spotlight rebuild has completed successfully.
    @State private var spotlightRebuildSucceeded = false
    /// Error message from a failed Spotlight rebuild.
    @State private var spotlightRebuildError: String? = nil

    /// How many downloaded volumes the hub lists before sending the rest behind one door.
    private static let inlineVolumeLimit = 3

    // MARK: - Body

    var body: some View {
        Form {
            heroSection
            if !appState.downloadQueue.isEmpty {
                activeDownloadsSection
            }
            addVolumesSection
            downloadedVolumesSection
            if !appState.interruptedVolumeIds.isEmpty {
                needsAttentionSection
            }
            keepingCurrentSection
            // R-5 P2: what the last updates did to the reader's annotated documents. One shared
            // view, mounted by BOTH hubs — the #900 rule, for the same reason.
            VolumeUpdateReviewSection()
            storageAndIndexSection
            // #900: one shared view, mounted by BOTH hubs. These two files are hand-maintained
            // twins, so a section written twice is two places for the same four numbers to drift.
            SemanticStorageSection()
            // V-5 s2: the query-encoder model section — same shared-view rule as above.
            SemanticModelSection()
            advancedSection
        }
        .navigationTitle(String(localized: "settings.hub.title", defaultValue: "Volumes & Storage"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadReport()
            // The live catalog is what makes "Check for Corrections" possible (it diffs blob SHAs
            // against `diffResult`), so it is still fetched on open. "Refresh Available List"
            // exists for asking again without leaving the screen.
            if appState.isOnline { await appState.manifestStore.refresh() }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.xml],
            allowsMultipleSelection: true
        ) { result in
            Task { await handleSideload(result) }
        }
        .sheet(isPresented: $showFreeUpSpaceSheet) {
            FreeUpSpaceSheet(
                plan: removalPlan,
                onRemove: { volumeIds in await removeVolumes(volumeIds) }
            )
            .environment(appState)
        }
        .alert(
            String(localized: "settings.hub.rebuild.title",
                   defaultValue: "Rebuild the search index from scratch?"),
            isPresented: $showRebuildConfirmation
        ) {
            Button(String(localized: "settings.hub.rebuild.confirm",
                          defaultValue: "Delete & Rebuild"), role: .destructive) {
                bulkIndexingFailureCount = nil
                Task { await rebuildIndex() }
            }
            Button(String(localized: "settings.hub.rebuild.cancel",
                          defaultValue: "Cancel"), role: .cancel) {}
        } message: {
            let volumes = HubCopy.volumes(storageReport?.perVolume.count ?? 0)
            Text(String(localized: "settings.hub.rebuild.message.v2",
                        defaultValue: "This deletes everything the app has built for searching — document text, cross-references, page numbers, dates and the people named in each document — and builds it again by re-reading all \(volumes) you have downloaded.\n\nYour research notes, highlights, summaries, collections, and tags are stored separately. They are not affected."))
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private var heroSection: some View {
        Section {
            SettingsHeroCard(
                title: String(localized: "settings.hub.hero.title", defaultValue: "Storage used"),
                value: ByteCountFormatter.string(
                    fromByteCount: Int64(storageReport?.grandTotalBytes ?? 0), countStyle: .file),
                status: librarySummary.text,
                needsAttention: librarySummary.needsAttention,
                visual: {
                    VStack(alignment: .leading, spacing: 6) {
                        SettingsUsageBar(breakdown: usageBreakdown)
                        SettingsUsageLegend(breakdown: usageBreakdown)
                        compactionRow
                    }
                },
                action: { EmptyView() }
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            if let loadError {
                SettingsStatusRow(
                    label: String(localized: "settings.hub.measureFailed",
                                  defaultValue: "Could not measure storage"),
                    detail: loadError,
                    state: .error
                )
            }
        }
    }

    // MARK: - Active Downloads

    @ViewBuilder
    private var activeDownloadsSection: some View {
        Section(String(localized: "settings.hub.active.header",
                       defaultValue: "Active Downloads")) {
            ForEach(appState.downloadQueue, id: \.self) { volumeId in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.manifestStore.entry(forVolumeId: volumeId)?.title ?? volumeId)
                            .lineLimit(1)
                        Text(volumeId)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Button(String(localized: "settings.hub.active.cancel",
                                  defaultValue: "Cancel")) {
                        Task { await appState.downloadManager?.cancelDownload(volumeId: volumeId) }
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                    .accessibilityLabel(
                        String(localized: "settings.hub.active.cancel.a11y",
                               defaultValue: "Cancel download for \(volumeId)"))
                }
            }
        }
    }

    // MARK: - Add Volumes

    @ViewBuilder
    private var addVolumesSection: some View {
        Section(String(localized: "settings.hub.add.header", defaultValue: "Add Volumes")) {
            NavigationLink {
                DownloadVolumesBrowseView()
                    .environment(appState)
            } label: {
                SettingsNavRow(
                    label: String(localized: "settings.hub.download.button",
                                  defaultValue: "Download from GitHub…"),
                    systemImage: "arrow.down.circle",
                    detail: String(localized: "settings.hub.download.detail",
                                   defaultValue: "Browse the whole catalogue, or take a subseries at once.")
                )
            }

            Button {
                isImporting = true
            } label: {
                SettingsNavRow(
                    label: String(localized: "settings.hub.sideload.button",
                                  defaultValue: "Sideload XML File…"),
                    systemImage: "square.and.arrow.down",
                    detail: String(localized: "settings.hub.sideload.detail",
                                   defaultValue: "Import a FRUS volume file you already have.")
                )
            }
            .buttonStyle(.plain)

            if !appState.isOnline {
                SettingsStatusRow(
                    label: String(localized: "settings.hub.offline.label", defaultValue: "Offline"),
                    detail: String(localized: "settings.hub.offline",
                                   defaultValue: "Offline — downloads start when you reconnect."),
                    state: .warning
                )
            }

            if let outcome = sideloadOutcome {
                sideloadOutcomeRow(outcome)
            }
        }
    }

    @ViewBuilder
    private func sideloadOutcomeRow(_ outcome: SideloadOutcome) -> some View {
        switch outcome {
        case .imported(let count):
            SettingsStatusRow(
                label: String(localized: "settings.hub.sideload.done",
                              defaultValue: "Imported \(HubCopy.volumes(count))"),
                detail: String(localized: "settings.hub.sideload.done.detail",
                               defaultValue: "Indexed and ready to search."),
                state: .ok
            )
        case .failed(let messages):
            SettingsStatusRow(
                label: String(localized: "settings.hub.sideload.failed",
                              defaultValue: "Import failed"),
                detail: messages.joined(separator: "\n"),
                state: .error
            )
        case .partial(let count, let messages):
            SettingsStatusRow(
                label: String(localized: "settings.hub.sideload.partial",
                              defaultValue: "Imported \(HubCopy.volumes(count)); some files were skipped"),
                detail: messages.joined(separator: "\n"),
                state: .warning
            )
        }
    }

    // MARK: - Downloaded Volumes

    @ViewBuilder
    private var downloadedVolumesSection: some View {
        Section(String(localized: "settings.hub.downloaded.header",
                       defaultValue: "Downloaded Volumes")) {
            if let report = storageReport {
                if report.perVolume.isEmpty {
                    Text(String(localized: "settings.hub.downloaded.empty.iOS.v2",
                                defaultValue: "No volumes on this device yet. Download them from GitHub, or add an XML file you already have."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(report.perVolume.prefix(Self.inlineVolumeLimit), id: \.volumeId) { entry in
                        SettingsNavRow(
                            label: appState.manifestStore.entry(forVolumeId: entry.volumeId)?.title
                                ?? entry.volumeId,
                            detail: entry.volumeId,
                            value: ByteCountFormatter.string(
                                fromByteCount: Int64(entry.volumeFileBytes), countStyle: .file)
                        )
                    }
                    if report.perVolume.count > Self.inlineVolumeLimit {
                        NavigationLink {
                            DownloadedVolumesListView(
                                entries: report.perVolume,
                                indexedVolumeIds: indexedVolumeIds,
                                protectedVolumeIds: protectedVolumeIds,
                                redownloadableVolumeIds: redownloadableVolumeIds,
                                lastOpenedByVolumeId: lastOpenedByVolumeId,
                                reindexingVolumeId: reindexingVolumeId,
                                onReindex: { volumeId in await reindexVolume(volumeId) },
                                onRemove: { volumeId in await removeVolumes([volumeId]) }
                            )
                            .environment(appState)
                        } label: {
                            Text(String(localized: "settings.hub.downloaded.showAll",
                                        defaultValue: "Show all \(report.perVolume.count)"))
                        }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(String(localized: "settings.hub.loading", defaultValue: "Measuring…"))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Needs Attention

    @ViewBuilder
    private var needsAttentionSection: some View {
        let interrupted = appState.interruptedVolumeIds.sorted()
        Section {
            ForEach(interrupted, id: \.self) { volumeId in
                SettingsStatusRow(
                    label: appState.manifestStore.entry(forVolumeId: volumeId)?.title ?? volumeId,
                    detail: String(localized: "settings.hub.interrupted.row",
                                   defaultValue: "Indexing was interrupted — re-index to restore search."),
                    state: .warning
                ) {
                    if reindexingInterruptedId == volumeId {
                        ProgressView()
                    } else {
                        Button(String(localized: "settings.hub.interrupted.reindex",
                                      defaultValue: "Re-index")) {
                            reindexInterrupted(volumeId: volumeId)
                        }
                        .buttonStyle(.borderless)
                        .disabled(actionsBusy)
                    }
                }
            }

            if interrupted.count > 1 {
                Button {
                    reindexAllInterrupted(interrupted)
                } label: {
                    if reindexingInterruptedId == "all" {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(String(localized: "settings.hub.interrupted.allRunning",
                                        defaultValue: "Re-indexing…"))
                        }
                    } else {
                        Text(String(localized: "settings.hub.interrupted.all",
                                    defaultValue: "Re-index All Interrupted"))
                    }
                }
                .disabled(actionsBusy)
            }
        } header: {
            Text(String(localized: "settings.hub.interrupted.header", defaultValue: "Needs Attention"))
        } footer: {
            Text(String(localized: "settings.hub.interrupted.footer.v2",
                        defaultValue: "These volumes were still being indexed when the app last closed. This section appears only when something needs your attention."))
        }
    }

    // MARK: - Keeping Current

    @ViewBuilder
    private var keepingCurrentSection: some View {
        Section {
            Button {
                Task { await checkForUpdates() }
            } label: {
                if isCheckingForUpdates {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(String(localized: "settings.hub.corrections.checking",
                                    defaultValue: "Checking…"))
                    }
                } else {
                    SettingsNavRow(
                        label: String(localized: "settings.hub.corrections.button",
                                      defaultValue: "Check for Corrections"),
                        systemImage: "arrow.triangle.2.circlepath",
                        detail: String(localized: "settings.hub.corrections.detail",
                                       defaultValue: "Re-download volumes changed upstream.")
                    )
                }
            }
            .buttonStyle(.plain)
            .disabled(isCheckingForUpdates
                      || (storageReport?.perVolume.isEmpty ?? true)
                      || appState.manifestStore.diffResult == nil)

            Button {
                Task { await refreshCatalog() }
            } label: {
                if isRefreshingCatalog {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(String(localized: "settings.hub.catalog.refreshing",
                                    defaultValue: "Refreshing…"))
                    }
                } else {
                    SettingsNavRow(
                        label: String(localized: "settings.hub.catalog.button",
                                      defaultValue: "Refresh Available List"),
                        systemImage: "arrow.clockwise",
                        // .v2: the old text promised newly published volumes. It cannot deliver
                        // them — every download surface reads `diffResult.known`, a filter over
                        // the BUNDLED manifest, so a volume published since this build shipped
                        // has no row to appear in (D-1 left that gap silent). What the refresh
                        // does deliver is real: corrected download URLs and sizes, and volumes
                        // withdrawn upstream dropping out of the list.
                        detail: String(localized: "settings.hub.catalog.detail.v2",
                                       defaultValue: "Re-read the published list to refresh sizes and download links.")
                    )
                }
            }
            .buttonStyle(.plain)
            .disabled(isRefreshingCatalog || !appState.isOnline)

            if !updatableVolumes.isEmpty {
                ForEach(updatableVolumes) { updatable in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(updatable.entry.title).lineLimit(2)
                            Text(updatable.entry.volumeId)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Button(String(localized: "settings.hub.corrections.update",
                                      defaultValue: "Update")) {
                            Task { await updateVolume(updatable) }
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Button {
                    Task { await updateAllVolumes() }
                } label: {
                    Text(String(localized: "settings.hub.corrections.updateAll",
                                defaultValue: "Update All"))
                }
            } else if hasCheckedForUpdates && !isCheckingForUpdates {
                SettingsStatusRow(
                    label: String(localized: "settings.hub.corrections.upToDate",
                                  defaultValue: "All downloaded volumes are up to date"),
                    detail: String(localized: "settings.hub.corrections.upToDate.detail",
                                   defaultValue: "Nothing has changed upstream since you downloaded them."),
                    state: .ok
                )
            }
        } header: {
            Text(String(localized: "settings.hub.keepingCurrent.header",
                        defaultValue: "Keeping Current"))
        } footer: {
            Text(String(localized: "settings.hub.keepingCurrent.footer",
                        defaultValue: "Updating re-downloads and re-indexes a volume. Your notes, highlights, tags, and summaries are preserved."))
        }
    }

    // MARK: - Storage & Index

    @ViewBuilder
    private var storageAndIndexSection: some View {
        Section {
            // The queue, so the card does not appear and disappear once per volume.
            if settingsBatch != nil || appState.indexingBatch != nil {
                indexingQueueCard
            }

            Button {
                showFreeUpSpaceSheet = true
            } label: {
                SettingsNavRow(
                    label: String(localized: "settings.hub.freeUp.button",
                                  defaultValue: "Free Up Space…"),
                    systemImage: "trash",
                    detail: freeUpSpaceDetail
                )
            }
            .buttonStyle(.plain)
            .disabled(storageReport == nil || removalPlan.isEmpty)

            Button {
                bulkIndexingFailureCount = nil
                Task { await indexRemaining() }
            } label: {
                SettingsNavRow(
                    label: String(localized: "settings.hub.indexRemaining.button",
                                  defaultValue: "Index Remaining"),
                    systemImage: "plus.circle",
                    detail: String(localized: "settings.hub.indexRemaining.detail",
                                   defaultValue: "Only volumes not yet indexed.")
                )
            }
            .buttonStyle(.plain)
            .disabled(actionsBusy || appState.indexingPipeline == nil)

            Button(role: .destructive) {
                showRebuildConfirmation = true
            } label: {
                SettingsNavRow(
                    label: String(localized: "settings.hub.rebuild.button",
                                  defaultValue: "Rebuild From Scratch"),
                    systemImage: "trash.circle",
                    detail: String(localized: "settings.hub.rebuild.detail",
                                   defaultValue: "Delete the index and re-index everything.")
                )
                .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .disabled(actionsBusy || appState.indexingPipeline == nil)

            if let failures = bulkIndexingFailureCount, failures > 0 {
                SettingsStatusRow(
                    label: String(localized: "settings.hub.indexFailures.v2",
                                  defaultValue: "\(HubCopy.volumes(failures)) could not be indexed"),
                    detail: String(localized: "settings.hub.indexFailures.detail.iOS",
                                   defaultValue: "Try Index Remaining again; if it keeps failing, Rebuild From Scratch."),
                    state: .error
                )
            }
        } header: {
            Text(String(localized: "settings.hub.storageIndex.header",
                        defaultValue: "Storage & Index"))
        } footer: {
            Text(String(localized: "settings.hub.storageIndex.footer",
                        defaultValue: "Notes, highlights, and tags are never affected. For reference: the full FRUS corpus is roughly 3.4 GB of XML plus 9–10 GB of search index."))
        }
    }

    /// The Free Up Space row's consequence line — how much is genuinely recoverable right now.
    private var freeUpSpaceDetail: String {
        let plan = removalPlan
        guard !plan.isEmpty else {
            return String(localized: "settings.hub.freeUp.detail.none",
                          defaultValue: "Every volume has notes, collections, or summaries attached.")
        }
        let total = plan.estimatedRecovery(for: Set(plan.candidates.map(\.volumeId)))
        let size = ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
        return String(localized: "settings.hub.freeUp.detail",
                      defaultValue: "\(HubCopy.volumes(plan.candidates.count)) removable · about \(size)")
    }

    // MARK: - Advanced

    @ViewBuilder
    private var advancedSection: some View {
        Section {
            IndexHealthView(actionsDisabled: actionsBusy)
        } header: {
            Text(String(localized: "settings.hub.advanced.header", defaultValue: "Advanced"))
        } footer: {
            Text(String(localized: "settings.storage.indexHealth.footer.v2",
                        defaultValue: "The app updates the index by itself when a new version improves how indexing works. Check Integrity runs a full check whenever you ask for one."))
        }

        Section {
            Button {
                Task { await runRebuildSpotlightIndex() }
            } label: {
                if spotlightRebuildRunning {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(String(localized: "settings.hub.spotlight.running",
                                    defaultValue: "Rebuilding…"))
                    }
                } else {
                    SettingsNavRow(
                        label: String(localized: "settings.hub.spotlight.label",
                                      defaultValue: "Spotlight Index"),
                        systemImage: "magnifyingglass",
                        detail: String(localized: "settings.hub.spotlight.detail",
                                       defaultValue: "Re-submit FRUS documents to system-wide search.")
                    )
                }
            }
            .buttonStyle(.plain)
            .disabled(actionsBusy || spotlightRebuildRunning || appState.indexingPipeline == nil)

            if spotlightRebuildSucceeded {
                SettingsStatusRow(
                    label: String(localized: "settings.hub.spotlight.ok",
                                  defaultValue: "Spotlight index rebuilt"),
                    detail: String(localized: "settings.hub.spotlight.ok.detail",
                                   defaultValue: "System-wide search can find these documents again."),
                    state: .ok
                )
            }
            if let error = spotlightRebuildError {
                SettingsStatusRow(
                    label: String(localized: "settings.hub.spotlight.failed",
                                  defaultValue: "Spotlight rebuild failed"),
                    detail: error,
                    state: .error
                )
            }
        }

        Section {
            Picker(
                String(localized: "settings.hub.concurrency.label",
                       defaultValue: "Concurrent downloads"),
                selection: $concurrentDownloadLimit
            ) {
                ForEach([1, 2, 3, 4, 6], id: \.self) { n in
                    Text("\(n)").tag(n)
                }
            }
            .onChange(of: concurrentDownloadLimit) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: SettingsKeys.concurrentDownloadLimit)
                if let dm = appState.downloadManager {
                    Task { await dm.setConcurrencyLimit(newValue) }
                }
            }

            Toggle(
                String(localized: "settings.hub.cellular.label",
                       defaultValue: "Allow Cellular Downloads"),
                isOn: $allowCellularDownloads
            )
            .accessibilityHint(
                String(localized: "settings.volumes.allowCellular.a11y",
                       defaultValue: "When off, volume downloads only proceed over Wi-Fi"))

            Toggle(
                String(localized: "settings.storage.liveActivity.label",
                       defaultValue: "Show Indexing Live Activity"),
                isOn: $liveActivityEnabled
            )
            .accessibilityHint(
                String(localized: "settings.storage.liveActivity.a11y",
                       defaultValue: "When off, indexing progress will not appear in the Dynamic Island or on the Lock Screen"))
        } header: {
            Text(String(localized: "settings.hub.options.header", defaultValue: "Options"))
        } footer: {
            Text(String(localized: "settings.hub.options.footer",
                        defaultValue: "Volume files are large; Wi-Fi is recommended. Downloaded XML is excluded from iCloud Backup — it can be re-downloaded at any time."))
        }
    }

    // MARK: - Inline Queue Progress Card

    /// Live batch progress, shown while `settingsBatch` is non-nil or the app is indexing.
    @ViewBuilder
    private var indexingQueueCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ProgressView()
                switch settingsBatch {
                case .indexRemaining(let current, let total):
                    Text(String(localized: "settings.storage.indexing.remaining",
                                defaultValue: "Volume \(current) of \(total)"))
                        .fontWeight(.medium)
                case .rebuildAll(let total):
                    Text(String(localized: "settings.storage.rebuilding.all",
                                defaultValue: "Rebuilding index for all \(total) volumes"))
                        .fontWeight(.medium)
                case nil:
                    Text(String(localized: "settings.storage.indexing.generic",
                                defaultValue: "Indexing…"))
                        .fontWeight(.medium)
                }
                Spacer()
                if let eta = queueETAString {
                    Text(eta)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }

            // `indexingBatch?.latest` rather than `currentIndexingProgress`: the
            // retained update keeps a volume name and a progress bar in the card during
            // the moment between two volumes, instead of blanking its body.
            if let update = appState.indexingBatch?.latest {
                Text(appState.manifestStore.entry(forVolumeId: update.volumeId)?.title
                     ?? update.volumeId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if update.totalDocuments > 0 {
                    ProgressView(value: Double(update.completedDocuments),
                                 total: Double(update.totalDocuments))
                        .progressViewStyle(.linear)

                    HStack {
                        Text(String(localized: "settings.storage.indexing.docCount",
                                    defaultValue: "\(update.completedDocuments) / \(update.totalDocuments) documents"))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Spacer()
                        if update.docsPerSecond > 0 {
                            Text(String(format: String(localized: "settings.storage.indexing.throughput",
                                                       defaultValue: "%.0f docs/s"),
                                        update.docsPerSecond))
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundStyle(.tertiary)
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(String(localized: "settings.storage.indexing.preparing",
                                    defaultValue: "Preparing…"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// Combined ETA for the current batch: remaining docs in the active volume
    /// plus remaining queued volumes (for "Index Remaining" batches).
    private var queueETAString: String? {
        guard let update = appState.indexingBatch?.latest else { return nil }
        var totalSeconds = 0.0

        if update.docsPerSecond > 0, update.totalDocuments > update.completedDocuments {
            let remaining = update.totalDocuments - update.completedDocuments
            totalSeconds += Double(remaining) / update.docsPerSecond
        }

        if case .indexRemaining(let current, let total) = settingsBatch {
            let remainingVolumes = total - current
            if remainingVolumes > 0 {
                let dps = appState.indexingQueueAverageDocsPerSecond > 0
                    ? appState.indexingQueueAverageDocsPerSecond
                    : update.docsPerSecond
                if dps > 0 {
                    let avgDocs = appState.indexingQueueAverageDocumentCount > 0
                        ? appState.indexingQueueAverageDocumentCount : 600
                    totalSeconds += Double(remainingVolumes) * Double(avgDocs) / dps
                }
            }
        }

        guard totalSeconds > 0 else { return nil }
        if totalSeconds < 60 {
            return String(localized: "settings.storage.indexing.eta.seconds",
                          defaultValue: "~\(Int(totalSeconds.rounded()))s remaining")
        }
        let minutes = Int((totalSeconds / 60).rounded())
        return String(localized: "settings.storage.indexing.eta.minutes",
                      defaultValue: "~\(minutes)m remaining")
    }

    // MARK: - Derived

    /// The storage split behind the hero's usage bar.
    private var usageBreakdown: StorageUsageBreakdown {
        guard let report = storageReport else {
            return StorageUsageBreakdown.make(volumeBytes: 0, indexBytes: 0, summaryBytes: 0)
        }
        return StorageUsageBreakdown.make(volumeBytes: report.totalVolumesBytes,
                                          indexBytes: report.totalIndexBytes,
                                          summaryBytes: report.totalSummariesBytes,
                                          vectorBytes: report.totalVectorBytes)
    }

    /// The hero's one-line state of the library.
    private var librarySummary: LibraryStatusSummary {
        let downloaded = storageReport?.perVolume.map(\.volumeId) ?? []
        return LibraryStatusSummary(
            downloadedCount: downloaded.count,
            catalogCount: catalogCount,
            indexedCount: downloaded.filter { indexedVolumeIds.contains($0) }.count,
            interruptedCount: appState.interruptedVolumeIds.count
        )
    }

    /// How many volumes the manifest knows about.
    ///
    /// Applies the same size floor the download browser does, so the hero's denominator can never
    /// disagree with the number of volumes the browser will actually offer.
    private var catalogCount: Int {
        let source = appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
        return source.filter { $0.sizeBytes >= 20_000 }.count
    }

    /// The ids the app can fetch again — the catalogue. Anything on disk and absent from this set
    /// is side-loaded: the app's copy is the only copy (#777).
    private var redownloadableVolumeIds: Set<String> {
        Set((appState.manifestStore.diffResult?.known
             ?? appState.manifestStore.bundledEntries).map(\.volumeId))
    }

    /// What Free Up Space may offer, and in what order.
    private var removalPlan: StorageRemovalPlan {
        StorageRemovalPlan.make(entries: storageReport?.perVolume ?? [],
                                protectedVolumeIds: protectedVolumeIds,
                                redownloadableVolumeIds: redownloadableVolumeIds,
                                lastOpenedByVolumeId: lastOpenedByVolumeId)
    }

    /// Whether an indexing operation of any kind is in flight.
    private var actionsBusy: Bool {
        settingsBatch != nil
            || appState.indexingBatch != nil
            || reindexingInterruptedId != nil
            || reindexingVolumeId != nil
    }

    // MARK: - Loading

    /// Refreshes the storage report and the three snapshots the body reads.
    ///
    /// `indexDirectory:` is not optional in practice — without it the parameter defaults to `nil`
    /// and `totalIndexBytes` comes back 0, which silently reports the largest thing on disk as
    /// weighing nothing.
    /// The compaction offer, under the usage bar.
    ///
    /// Renders nothing when there is little to reclaim, states the figure when there is but the
    /// disk cannot take it, and offers the action when it can. The shared `IndexCompaction` rule
    /// decides which — both platforms render the same three cases from the same decision, which is
    /// the point of putting it in one place.
    @ViewBuilder
    private var compactionRow: some View {
        if let subtitle = IndexCompaction.subtitle(for: compactionAvailability) {
            VStack(alignment: .leading, spacing: 6) {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if case .available = compactionAvailability {
                    HStack(spacing: 8) {
                        Button {
                            Task { await compactIndex() }
                        } label: {
                            Label(String(localized: "settings.storage.compact.action",
                                         defaultValue: "Compact Database"),
                                  systemImage: "arrow.down.right.and.arrow.up.left")
                        }
                        .disabled(isCompacting)
                        #if os(macOS)
                        .buttonStyle(.link)
                        #endif
                        if isCompacting { ProgressView().controlSize(.small) }
                    }
                    Text(String(localized: "settings.storage.compact.caveat",
                                defaultValue: "Rewrites the index to give the free space back. Searching is unavailable while it runs — usually a few seconds, longer on a large library. Nothing you have written is affected."))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.top, 4)
        }
        if let compactedBytes {
            Text(String(format: String(localized: "settings.storage.compact.done %@",
                                       defaultValue: "Reclaimed %@."),
                        ByteCountFormatter.string(fromByteCount: Int64(compactedBytes), countStyle: .file)))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Whether to offer compacting the index, decided by the shared `IndexCompaction` rule.
    private var compactionAvailability: IndexCompaction.Availability {
        IndexCompaction.availability(statistics: indexPages, availableBytes: availableBytes)
    }

    /// Reads the page split and the free space behind the compaction offer.
    ///
    /// Both are cheap: three pragmas and one `URLResourceValues` read. Refreshed with the storage
    /// report so the offer cannot describe a file that has since changed.
    private func refreshIndexPages() async {
        guard let pipeline = appState.indexingPipeline else {
            indexPages = nil
            return
        }
        indexPages = try? await pipeline.indexPageStatistics()
        // `volumeAvailableCapacityForImportantUsage` is the figure that accounts for purgeable
        // space, which is what a large write can actually claim.
        if let directory = appState.indexDirectory,
           let values = try? directory.resourceValues(
               forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let capacity = values.volumeAvailableCapacityForImportantUsage {
            availableBytes = Int(capacity)
        } else {
            availableBytes = nil
        }
    }

    /// Compacts the index, then rebuilds what the compaction invalidated.
    ///
    /// The `refreshReadOnlyStores()` call is not optional and not cosmetic: VACUUM replaces the
    /// database file underneath the boot-once cross-reference / person-mention / page-range
    /// connections, and without recreating them they read empty for the rest of the session
    /// (#275). The bulk-removal path already does this; this one must too.
    private func compactIndex() async {
        guard let pipeline = appState.indexingPipeline, !isCompacting else { return }
        let before = indexPages?.fileBytes
        isCompacting = true
        defer { isCompacting = false }
        do {
            try await pipeline.vacuumIndex()
        } catch {
            loadError = error.localizedDescription
            return
        }
        appState.refreshAfterCorpusChange(context: modelContext)
        await refreshIndexPages()
        if let before, let after = indexPages?.fileBytes, before > after {
            compactedBytes = before - after
        }
        await loadReport()
    }

    private func loadReport() async {
        guard let dm = appState.downloadManager else { return }
        do {
            storageReport = try await dm.storageReport(indexDirectory: appState.indexDirectory)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
        await refreshIndexPages()
        refreshSnapshots()
    }

    /// Recomputes `protectedVolumeIds`, `lastOpenedByVolumeId`, and `indexedVolumeIds` with
    /// one-shot fetches. See the live-query hazard note on the type.
    @MainActor
    private func refreshSnapshots() {
        var protected = Set<String>()
        if let notes = try? modelContext.fetch(FetchDescriptor<ResearchNote>()) {
            notes.forEach { protected.insert($0.volumeId) }
        }
        if let entries = try? modelContext.fetch(FetchDescriptor<CollectionEntry>()) {
            entries.forEach { protected.insert($0.volumeId) }
        }
        if let summaries = try? modelContext.fetch(FetchDescriptor<GeneratedSummary>()) {
            summaries.forEach { protected.insert($0.volumeId) }
        }
        protectedVolumeIds = protected

        var lastOpened: [String: Date] = [:]
        let descriptor = FetchDescriptor<ReadingHistoryEntry>(
            sortBy: [SortDescriptor(\.accessedAt, order: .reverse)]
        )
        if let historyRows = try? modelContext.fetch(descriptor) {
            for entry in historyRows where lastOpened[entry.volumeId] == nil {
                if let date = entry.accessedAt { lastOpened[entry.volumeId] = date }
            }
        }
        lastOpenedByVolumeId = lastOpened

        if let pipeline = appState.indexingPipeline, let report = storageReport {
            indexedVolumeIds = Set(report.perVolume.map(\.volumeId).filter {
                (try? pipeline.isVolumeIndexed($0)) == true
            })
        } else {
            indexedVolumeIds = []
        }
    }

    // MARK: - Sideload

    /// The three shapes a multi-file sideload can end in.
    private enum SideloadOutcome {
        /// Every chosen file imported.
        case imported(count: Int)
        /// Some imported, some did not.
        case partial(count: Int, messages: [String])
        /// Nothing imported.
        case failed(messages: [String])
    }

    /// Imports the chosen XML files through `SideloadValidator`, the same path macOS now uses.
    ///
    /// The old `SideloadView` allowed a single file; the hub allows several, running the validator
    /// per file so one bad file does not discard the good ones.
    private func handleSideload(_ result: Result<[URL], Error>) async {
        guard let dm = appState.downloadManager,
              let pipeline = appState.indexingPipeline else { return }

        switch result {
        case .failure(let error):
            sideloadOutcome = .failed(messages: [error.localizedDescription])
        case .success(let urls):
            var imported = 0
            var messages: [String] = []
            let validator = SideloadValidator()

            for url in urls {
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                do {
                    let volumeId = try validator.validate(url: url,
                                                          volumesDirectory: dm.volumesDirectory)
                    try await pipeline.indexVolume(volumeId)
                    imported += 1
                } catch {
                    messages.append("\(url.lastPathComponent): \(error.localizedDescription)")
                }
            }

            if imported > 0 {
                // The new volume added aux-table rows the boot read-only connections can't see (#275).
                appState.refreshAfterCorpusChange(context: modelContext)
            }
            if messages.isEmpty {
                sideloadOutcome = .imported(count: imported)
            } else if imported > 0 {
                sideloadOutcome = .partial(count: imported, messages: messages)
            } else {
                sideloadOutcome = .failed(messages: messages)
            }
            await loadReport()
        }
    }

    // MARK: - Keeping Current actions

    /// Re-reads the FRUS repository's volume list so newly published volumes appear.
    private func refreshCatalog() async {
        isRefreshingCatalog = true
        await appState.manifestStore.refresh()
        isRefreshingCatalog = false
    }

    /// Diffs every downloaded volume's git blob SHA against the live manifest.
    /// Runs only on explicit user request — hashing every downloaded volume is too costly to run
    /// silently at launch.
    private func checkForUpdates() async {
        guard let dm = appState.downloadManager,
              let liveInfo = appState.manifestStore.diffResult?.liveInfoByVolumeId else { return }
        isCheckingForUpdates = true
        let known = appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
        updatableVolumes = await VolumeUpdateChecker.updatableVolumes(
            known: known,
            liveInfoByVolumeId: liveInfo,
            downloadManager: dm
        )
        hasCheckedForUpdates = true
        isCheckingForUpdates = false
    }

    /// Re-downloads `updatable`, overwriting the stale local copy. `onVolumeDownloaded`
    /// re-indexes it once the transfer completes; the UPSERT path preserves user data.
    private func updateVolume(_ updatable: UpdatableVolume) async {
        guard let dm = appState.downloadManager else { return }
        await dm.enqueueDownload(updatable.entry, force: true)
        updatableVolumes.removeAll { $0.id == updatable.id }
    }

    /// Re-downloads every volume currently listed as updatable.
    private func updateAllVolumes() async {
        for updatable in updatableVolumes {
            await updateVolume(updatable)
        }
    }

    // MARK: - Indexing actions

    private func reindexVolume(_ volumeId: String) async {
        guard let pipeline = appState.indexingPipeline else { return }
        reindexingVolumeId = volumeId
        try? await pipeline.indexVolume(volumeId)
        // The single-volume reindex mutated the aux tables — reopen the read-only stores (#275).
        appState.refreshAfterCorpusChange(context: modelContext)
        reindexingVolumeId = nil
        await loadReport()
    }

    private func reindexInterrupted(volumeId: String) {
        guard let pipeline = appState.indexingPipeline else { return }
        reindexingInterruptedId = volumeId
        Task {
            try? await pipeline.indexVolume(volumeId)
            appState.refreshAfterCorpusChange(context: modelContext)
            reindexingInterruptedId = nil
            await loadReport()
        }
    }

    private func reindexAllInterrupted(_ volumeIds: [String]) {
        guard let pipeline = appState.indexingPipeline else { return }
        reindexingInterruptedId = "all"
        Task {
            for volumeId in volumeIds {
                do {
                    try await pipeline.indexVolume(volumeId)
                } catch {
                    #if DEBUG
                    print("[VolumesStorageHubView] Re-index interrupted volume \(volumeId) failed: \(error)")
                    #endif
                }
            }
            appState.refreshAfterCorpusChange(context: modelContext)
            reindexingInterruptedId = nil
            await loadReport()
        }
    }

    private func indexRemaining() async {
        guard let pipeline = appState.indexingPipeline,
              let report = storageReport else { return }
        let unindexed = report.perVolume.filter {
            (try? pipeline.isVolumeIndexed($0.volumeId)) != true
        }
        guard !unindexed.isEmpty else { return }
        var failures = 0
        for (idx, entry) in unindexed.enumerated() {
            settingsBatch = .indexRemaining(current: idx + 1, total: unindexed.count)
            do {
                try await pipeline.indexVolume(entry.volumeId)
            } catch {
                failures += 1
            }
        }
        // Newly indexed volumes added rows the boot read-only connections can't see (#275).
        appState.refreshAfterCorpusChange(context: modelContext)
        settingsBatch = nil
        bulkIndexingFailureCount = failures > 0 ? failures : nil
        await loadReport()
    }

    /// Wipes the entire search index, then rebuilds it from all downloaded volumes.
    ///
    /// A single `DELETE FROM` per table first, rather than relying on the per-volume pre-deletes
    /// inside `storeIndexData` — that is what clears rows orphaned by deleted volumes, duplicate
    /// page ranges from earlier bugs, and accumulated FTS5 b-tree fragmentation.
    ///
    /// User data (notes, highlights, summaries, collections, tags) lives in SwiftData and is
    /// completely unaffected.
    private func rebuildIndex() async {
        guard let pipeline = appState.indexingPipeline else { return }
        let total = storageReport?.perVolume.count ?? 0
        settingsBatch = .rebuildAll(total: total)
        do {
            try await pipeline.removeAllVolumesFromIndex()
            appState.indexedVolumeIds = []
        } catch {
            // Wipe failed; abort rather than re-indexing on top of a partially-deleted index.
            settingsBatch = nil
            bulkIndexingFailureCount = total
            await loadReport()
            return
        }
        try? await pipeline.indexAllVolumes()
        // Reopen the read-only stores post-rebuild so analytics / citation lookup don't read the
        // stale boot connections (#275).
        appState.refreshAfterCorpusChange(context: modelContext)
        settingsBatch = nil
        await loadReport()
        let indexed = storageReport?.perVolume.filter { indexedVolumeIds.contains($0.volumeId) }.count ?? 0
        let failures = (storageReport?.perVolume.count ?? 0) - indexed
        bulkIndexingFailureCount = failures > 0 ? failures : nil
    }

    /// Removes volumes and their index rows, then compacts the index if more than one went.
    ///
    /// Shared by the single-volume Remove in the full list and the multi-select Free Up Space
    /// sheet, so both obey the same post-removal contract: the read-only stores are reopened
    /// (#275) and the report is re-measured.
    private func removeVolumes(_ volumeIds: [String]) async {
        guard let dm = appState.downloadManager,
              let pipeline = appState.indexingPipeline else { return }
        for volumeId in volumeIds {
            try? await pipeline.removeVolume(volumeId)
            appState.indexedVolumeIds.remove(volumeId)
            try? await dm.deleteVolume(volumeId: volumeId)
        }
        if volumeIds.count > 1 {
            // VACUUM after a bulk removal to shrink the index file immediately. Skipped for a
            // single removal, where the pause is not worth the few megabytes.
            try? await pipeline.vacuumIndex()
        }
        // Removing volumes deleted their aux-table rows — reopen the read-only stores so analytics
        // don't keep counting them (#275).
        appState.refreshAfterCorpusChange(context: modelContext)
        await loadReport()
    }

    /// Clears and re-submits the system Spotlight index from `document_cache`, without
    /// re-parsing XML.
    private func runRebuildSpotlightIndex() async {
        guard let pipeline = appState.indexingPipeline else { return }
        spotlightRebuildRunning = true
        spotlightRebuildSucceeded = false
        spotlightRebuildError = nil
        do {
            try await pipeline.rebuildSpotlightIndex()
            spotlightRebuildSucceeded = true
        } catch {
            spotlightRebuildError = error.localizedDescription
        }
        spotlightRebuildRunning = false
    }
}

// MARK: - DownloadedVolumesListView

/// The full downloaded-volume list, behind the hub's "Show all N" row (S-2c).
///
/// A push rather than a sheet — this is a drill-down into what the hub summarised, and iOS
/// navigation says so with a back button. The macOS twin is a sheet because the Settings window
/// has no navigation chrome.
///
/// Version history:
///   1.0 — S-2c: initial implementation, from `StorageManagementView`'s per-volume section
private struct DownloadedVolumesListView: View {

    /// Every downloaded volume, from the host's storage report.
    let entries: [VolumeStorageEntry]
    /// Volumes present in the search index.
    let indexedVolumeIds: Set<String>
    /// Volumes carrying user data, marked and never auto-removed.
    let protectedVolumeIds: Set<String>
    /// The ids the app can fetch again. A volume absent from this set was side-loaded and its
    /// removal is irreversible, which the confirmation has to say (#777).
    let redownloadableVolumeIds: Set<String>
    /// Most recent open per volume.
    let lastOpenedByVolumeId: [String: Date]
    /// The volume the host is currently re-indexing, if any.
    let reindexingVolumeId: String?
    /// Re-index one volume.
    let onReindex: (String) async -> Void
    /// Remove one volume and its index rows.
    let onRemove: (String) async -> Void

    @Environment(AppState.self) private var appState

    @State private var filter = ""
    @State private var pendingRemoval: String? = nil

    private var filtered: [VolumeStorageEntry] {
        let needle = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return entries }
        return entries.filter { entry in
            let title = appState.manifestStore.entry(forVolumeId: entry.volumeId)?.title ?? ""
            return "\(entry.volumeId)\n\(title)".range(
                of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    var body: some View {
        List {
            if filtered.isEmpty {
                ContentUnavailableView(
                    String(localized: "settings.hub.allVolumes.none", defaultValue: "No Matches"),
                    systemImage: "magnifyingglass",
                    description: Text(String(localized: "settings.hub.allVolumes.none.detail",
                                             defaultValue: "No downloaded volume matches that filter."))
                )
            } else {
                ForEach(filtered, id: \.volumeId) { entry in
                    row(entry)
                }
            }
        }
        // `.always`, not the default: this screen exists because 552 rows are unusable without
        // a filter, so the field has to be visible rather than hidden until the user thinks to
        // pull down on the list.
        .searchable(text: $filter,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: Text(String(localized: "settings.hub.allVolumes.filter",
                                        defaultValue: "Filter by title or volume ID")))
        .navigationTitle(String(localized: "settings.hub.allVolumes.title.iOS",
                                defaultValue: "Volumes on This Device"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            String(localized: "settings.hub.remove.title", defaultValue: "Remove this volume?"),
            isPresented: Binding(get: { pendingRemoval != nil },
                                 set: { if !$0 { pendingRemoval = nil } }),
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.hub.remove.confirm", defaultValue: "Remove"),
                   role: .destructive) {
                if let volumeId = pendingRemoval {
                    pendingRemoval = nil
                    Task { await onRemove(volumeId) }
                }
            }
            Button(String(localized: "settings.hub.rebuild.cancel", defaultValue: "Cancel"),
                   role: .cancel) { pendingRemoval = nil }
        } message: {
            // #777: a side-loaded volume cannot be downloaded again — the app's copy is the
            // user's only copy, and it is written with `isExcludedFromBackupKey`, so it is in no
            // iCloud Backup or Time Machine either. Promising a re-download there was the whole
            // bug: the sentence is what makes the button feel safe.
            if let volumeId = pendingRemoval, !redownloadableVolumeIds.contains(volumeId) {
                Text(String(localized: "settings.hub.remove.message.iOS.sideloaded",
                            defaultValue: "The XML file and its search-index rows are deleted from this device. Your notes, highlights, tags, and summaries for it are kept. **This volume was side-loaded, so the app cannot download it again** — if you no longer have the file, this cannot be undone."))
            } else {
                Text(String(localized: "settings.hub.remove.message.iOS",
                            defaultValue: "The XML file and its search-index rows are deleted from this device. Your notes, highlights, tags, and summaries for it are kept, and the volume can be downloaded again."))
            }
        }
    }

    @ViewBuilder
    private func row(_ entry: VolumeStorageEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(appState.manifestStore.entry(forVolumeId: entry.volumeId)?.title
                         ?? entry.volumeId)
                        .lineLimit(2)
                    if protectedVolumeIds.contains(entry.volumeId) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(
                                String(localized: "settings.hub.protected.a11y",
                                       defaultValue: "Has attached research data"))
                    }
                }
                Text(statusLine(entry))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if reindexingVolumeId == entry.volumeId {
                ProgressView()
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingRemoval = entry.volumeId
            } label: {
                Label(String(localized: "settings.hub.allVolumes.remove", defaultValue: "Remove"),
                      systemImage: "trash")
            }
            Button {
                Task { await onReindex(entry.volumeId) }
            } label: {
                Label(String(localized: "settings.hub.allVolumes.reindex", defaultValue: "Re-index"),
                      systemImage: "arrow.clockwise")
            }
            .tint(.blue)
        }
    }

    /// Size · index state · last opened, in one line.
    private func statusLine(_ entry: VolumeStorageEntry) -> String {
        let size = ByteCountFormatter.string(fromByteCount: Int64(entry.volumeFileBytes),
                                             countStyle: .file)
        let indexState = indexedVolumeIds.contains(entry.volumeId)
            ? String(localized: "settings.hub.allVolumes.indexed", defaultValue: "indexed")
            : String(localized: "settings.hub.allVolumes.notIndexed", defaultValue: "not indexed")
        let opened: String
        if let date = lastOpenedByVolumeId[entry.volumeId] {
            opened = String(localized: "settings.hub.allVolumes.opened",
                            defaultValue: "opened \(date.formatted(.relative(presentation: .named)))")
        } else {
            opened = String(localized: "settings.hub.allVolumes.neverOpened",
                            defaultValue: "never opened")
        }
        return "\(entry.volumeId) · \(size) · \(indexState) · \(opened)"
    }
}

// MARK: - DownloadVolumesBrowseView

/// The GitHub download browser, behind the hub's "Download from GitHub…" row (S-2c).
///
/// The catalogue leaves the settings form entirely: choosing what to download is its own task, and
/// inlining 552 rows made the hub's other sections unreachable without scrolling past every volume
/// ever published. Search leads, because picking one volume out of 552 by scrolling is not a real
/// interaction.
///
/// Version history:
///   1.0 — S-2c: initial implementation, from `DownloadsSettingsView`'s Find Volumes section
private struct DownloadVolumesBrowseView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    /// What the user is choosing to download.
    private enum ScopeChoice: Int, CaseIterable, Identifiable {
        case corpus, subseries, volume
        var id: Int { rawValue }

        var label: String {
            switch self {
            case .corpus:
                return String(localized: "settings.hub.browse.corpus", defaultValue: "Entire Corpus")
            case .subseries:
                return String(localized: "settings.hub.browse.subseries.short", defaultValue: "Subseries")
            case .volume:
                return String(localized: "settings.hub.browse.volumes.short", defaultValue: "Volumes")
            }
        }
    }

    @State private var scopeChoice: ScopeChoice = .corpus
    @State private var selectedSubseries: Set<String> = []
    @State private var selectedVolumeIds: Set<String> = []
    @State private var filter = ""
    @State private var isEnqueuing = false

    var body: some View {
        List {
            Section {
                Picker(String(localized: "settings.hub.browse.scope",
                              defaultValue: "Download"), selection: $scopeChoice) {
                    ForEach(ScopeChoice.allCases) { choice in
                        Text(choice.label).tag(choice)
                    }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text(scopeFooter)
            }

            switch scopeChoice {
            case .corpus:
                EmptyView()
            case .subseries:
                Section(String(localized: "settings.hub.browse.subseries",
                               defaultValue: "One or More Subseries")) {
                    ForEach(filteredSubseries, id: \.self) { sub in
                        let count = allVolumes.filter { $0.subseries == sub }.count
                        Button {
                            toggle(&selectedSubseries, sub)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sub).foregroundStyle(.primary)
                                    Text(HubCopy.volumes(count))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedSubseries.contains(sub) {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedSubseries.contains(sub) ? .isSelected : [])
                    }
                }
            case .volume:
                Section(String(localized: "settings.hub.browse.volumes",
                               defaultValue: "Individual Volumes")) {
                    ForEach(filteredVolumes) { vol in
                        Button {
                            toggle(&selectedVolumeIds, vol.volumeId)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(vol.title).foregroundStyle(.primary).lineLimit(2)
                                    Text("\(vol.subseries) · \(vol.volumeId)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedVolumeIds.contains(vol.volumeId) {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedVolumeIds.contains(vol.volumeId) ? .isSelected : [])
                    }
                }
            }
        }
        // See the note on the volume list: search leads on this screen by design.
        .searchable(text: $filter,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: Text(String(localized: "settings.hub.browse.filter",
                                        defaultValue: "Filter by title, volume ID, or subseries")))
        .navigationTitle(String(localized: "settings.hub.browse.title",
                                defaultValue: "Download from GitHub"))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if !appState.isOnline {
                    Label(String(localized: "settings.hub.offline",
                                 defaultValue: "Offline — downloads start when you reconnect."),
                          systemImage: "wifi.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(selectionSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        Task { await enqueueSelected() }
                    } label: {
                        if isEnqueuing {
                            ProgressView()
                        } else {
                            Text(String(localized: "settings.hub.browse.download",
                                        defaultValue: "Download"))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canDownload || isEnqueuing)
                }
            }
            .padding()
            .background(.bar)
        }
    }

    // MARK: Derived

    private func toggle(_ set: inout Set<String>, _ value: String) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    /// The catalogue, minus anything too small to be a real volume.
    ///
    /// The size floor guards against placeholder or stub XML appearing in a *live* manifest
    /// refresh; measured against the bundled manifest it currently excludes nothing (0 of 552
    /// entries fall under it). The old iOS pane applied no floor and the macOS one did — this is
    /// the two platforms agreeing.
    private var allVolumes: [VolumeManifestEntry] {
        let source = appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
        return source.filter { $0.sizeBytes >= 20_000 }
    }

    private var allSubseries: [String] {
        Set(allVolumes.map(\.subseries)).sorted { startYear($0) > startYear($1) }
    }

    private var needle: String {
        filter.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredSubseries: [String] {
        guard !needle.isEmpty else { return allSubseries }
        return allSubseries.filter {
            $0.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    private var filteredVolumes: [VolumeManifestEntry] {
        guard !needle.isEmpty else { return allVolumes }
        return allVolumes.filter { vol in
            "\(vol.title)\n\(vol.volumeId)\n\(vol.subseries)".range(
                of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    private var scopeFooter: String {
        switch scopeChoice {
        case .corpus:
            let bytes = allVolumes.reduce(0) { $0 + $1.sizeBytes }
            let xml = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
            return String(localized: "settings.hub.browse.corpus.detail",
                          defaultValue: "\(HubCopy.volumes(allVolumes.count)) · \(xml) of XML, plus roughly 2.8× that in search index. Downloads run in the background and resume across launches.")
        case .subseries:
            return String(localized: "settings.hub.browse.subseries.detail",
                          defaultValue: "Choose one or more decades or diplomatic eras.")
        case .volume:
            return String(localized: "settings.hub.browse.volumes.detail",
                          defaultValue: "Select specific volumes from any subseries.")
        }
    }

    private var selectionSummary: String {
        switch scopeChoice {
        case .corpus:
            return String(localized: "settings.hub.browse.summary.corpus",
                          defaultValue: "\(HubCopy.volumes(allVolumes.count)) will be queued")
        case .subseries:
            let count = allVolumes.filter { selectedSubseries.contains($0.subseries) }.count
            return String(localized: "settings.hub.browse.summary.subseries",
                          defaultValue: "\(HubCopy.subseries(selectedSubseries.count)) · \(HubCopy.volumes(count))")
        case .volume:
            return String(localized: "settings.hub.browse.summary.volumes",
                          defaultValue: "\(HubCopy.volumes(selectedVolumeIds.count)) selected")
        }
    }

    private func startYear(_ subseries: String) -> Int {
        Int(subseries.prefix(4)) ?? 0
    }

    private var canDownload: Bool {
        switch scopeChoice {
        case .corpus:    return !allVolumes.isEmpty
        case .subseries: return !selectedSubseries.isEmpty
        case .volume:    return !selectedVolumeIds.isEmpty
        }
    }

    // MARK: Actions

    private func enqueueSelected() async {
        guard let dm = appState.downloadManager else { return }
        isEnqueuing = true
        defer { isEnqueuing = false }

        let volumes: [VolumeManifestEntry]
        switch scopeChoice {
        case .corpus:
            volumes = allVolumes
        case .subseries:
            volumes = allVolumes.filter { selectedSubseries.contains($0.subseries) }
        case .volume:
            volumes = allVolumes.filter { selectedVolumeIds.contains($0.volumeId) }
        }

        for entry in volumes {
            await dm.enqueueDownload(entry)
        }
        dismiss()
    }
}

// MARK: - FreeUpSpaceSheet

/// The Free Up Space sheet — the iOS port of the macOS Manage Storage flow (S-2c).
///
/// Lists downloaded volumes with no attached notes, collections, or summaries, least-recently-used
/// first, with a running estimate of recoverable space. The eligibility and ordering rules are
/// `StorageRemovalPlan`'s, shared with macOS, so the two platforms cannot drift into offering
/// different volumes.
///
/// Version history:
///   1.0 — S-2c: initial implementation, porting `MacManageStorageSheet` to iOS
private struct FreeUpSpaceSheet: View {

    /// What may be removed, and in what order.
    let plan: StorageRemovalPlan
    /// Removes the chosen volumes; the host re-measures afterwards.
    let onRemove: ([String]) async -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Set<String> = []
    @State private var isRemoving = false
    @State private var showConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if plan.isEmpty {
                    ContentUnavailableView(
                        String(localized: "settings.hub.freeUp.none",
                               defaultValue: "No Removable Volumes"),
                        systemImage: "lock.shield",
                        description: Text(String(localized: "settings.hub.freeUp.none.detail.iOS",
                                                 defaultValue: "Every downloaded volume has attached notes, collections, or summaries. Remove those individually from the full volume list."))
                    )
                } else {
                    List {
                        Section {
                            ForEach(plan.candidates) { candidate in
                                candidateRow(candidate)
                            }
                        } header: {
                            Text(String(localized: "settings.hub.freeUp.header",
                                        defaultValue: "Least recently used first"))
                        } footer: {
                            Text(String(localized: "settings.hub.freeUp.estimateNote",
                                        defaultValue: "Each size is the XML file plus an estimated 2.8× for its share of the search index. That ratio comes from the full corpus: about 9–10 GB of index for about 3.4 GB of XML. Per volume the overhead runs from roughly 2.5× to 3×, so treat these sizes as approximate."))
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "settings.hub.freeUp.title",
                                    defaultValue: "Free Up Space"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "settings.hub.rebuild.cancel", defaultValue: "Cancel")) {
                        dismiss()
                    }
                    .disabled(isRemoving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isRemoving {
                        ProgressView()
                    } else {
                        Button(String(localized: "settings.hub.freeUp.remove",
                                      defaultValue: "Remove \(HubCopy.volumes(selected.count))")) {
                            showConfirmation = true
                        }
                        .disabled(selected.isEmpty)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !plan.isEmpty {
                    Text(recoveryLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.bar)
                }
            }
            .confirmationDialog(
                String(localized: "settings.hub.freeUp.confirm.title",
                       defaultValue: "Remove these volumes?"),
                isPresented: $showConfirmation,
                titleVisibility: .visible
            ) {
                Button(String(localized: "settings.hub.remove.confirm", defaultValue: "Remove"),
                       role: .destructive) {
                    Task { await performRemoval() }
                }
                Button(String(localized: "settings.hub.rebuild.cancel", defaultValue: "Cancel"),
                       role: .cancel) {}
            } message: {
                Text(String(localized: "settings.hub.freeUp.confirm.message",
                            defaultValue: "The XML files and their search-index rows are deleted from this device. Every one of these volumes can be downloaded again."))
            }
            .interactiveDismissDisabled(isRemoving)
        }
    }

    @ViewBuilder
    private func candidateRow(_ candidate: StorageRemovalPlan.Candidate) -> some View {
        let isSelected = selected.contains(candidate.volumeId)
        Button {
            if isSelected { selected.remove(candidate.volumeId) } else { selected.insert(candidate.volumeId) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.manifestStore.entry(forVolumeId: candidate.volumeId)?.title
                         ?? candidate.volumeId)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(subtitle(candidate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text("~\(ByteCountFormatter.string(fromByteCount: Int64(candidate.estimatedBytes), countStyle: .file))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // A5: expose selection as a trait, not just the symbol swap.
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func subtitle(_ candidate: StorageRemovalPlan.Candidate) -> String {
        if let date = candidate.lastOpened {
            return String(localized: "settings.hub.freeUp.opened",
                          defaultValue: "Opened \(date.formatted(.relative(presentation: .named)))")
        }
        return String(localized: "settings.hub.freeUp.neverOpened", defaultValue: "Never opened")
    }

    private var recoveryLine: String {
        guard !selected.isEmpty else {
            return String(localized: "settings.hub.freeUp.selectPrompt",
                          defaultValue: "Select volumes to see estimated recovery")
        }
        let size = ByteCountFormatter.string(
            fromByteCount: Int64(plan.estimatedRecovery(for: selected)), countStyle: .file)
        return String(localized: "settings.hub.freeUp.recovery",
                      defaultValue: "~\(size) estimated recovery")
    }

    private func performRemoval() async {
        isRemoving = true
        await onRemove(Array(selected))
        isRemoving = false
        selected = []
        dismiss()
    }
}

#endif
