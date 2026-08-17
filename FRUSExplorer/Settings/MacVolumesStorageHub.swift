// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(macOS)

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - MacVolumesStorageHub

/// The macOS **Volumes & Storage** destination — everything about getting the corpus onto this
/// Mac and keeping it searchable, in one pane (S-2b).
///
/// ## What this replaces
/// Two separate sidebar rows, `SettingsStoragePane` ("Storage") and `SettingsAddVolumesPane`
/// ("Add Volumes"), which between them split one job across two screens: you added volumes in one
/// and discovered how much room they took, whether they were indexed, and how to get rid of them
/// in the other. The North Star IA (`1c`) merges them, and this is the merged pane.
///
/// ## Reading order
/// Status first, then actions — the reader learns where the library stands before being offered a
/// button:
///
/// 1. **Hero** — the usage bar, the one-line library summary, and the two ways in
///    (Download from GitHub · Sideload XML File).
/// 2. **Downloaded Volumes** — the first few, then the full list behind one door.
/// 3. **Needs Attention** — shown *only* when volumes were interrupted mid-index.
/// 4. **Keeping Current** — the two upstream scans, which no longer read alike.
/// 5. **Storage & Index** — free space, index what's missing, rebuild from scratch.
/// 6. **Advanced** — index health, Spotlight, download concurrency.
///
/// ## Native form, not hand-rolled chrome
/// The old panes were `ScrollView` + hand-built section headers and 11-point `Text` captions. This
/// is a real `Form(.grouped)`, which is what the plan's S-5 was going to convert them to anyway —
/// converting two panes only to delete them would have been wasted work, so the hub is born in the
/// native idiom and S-5's list drops "Storage" and "Add Volumes".
///
/// ## What this pane surfaces that macOS never had
/// `AppState.interruptedVolumeIds` — volumes whose indexing pass was killed with the app — has
/// been tracked since Session 115 and rendered on iOS only. On macOS the volumes simply came back
/// missing from search with nothing to explain it. "Needs Attention" is that state, with its
/// remedy attached.
///
/// ## Live-query hazard (do not "improve" this)
/// `protectedVolumeIds` and `lastOpenedByVolumeId` are one-shot fetches refreshed by
/// `loadReport()`, deliberately **not** `@Query`. A `@Query` re-renders the whole pane on every
/// change to its model type, so CloudKit drip-importing notes/summaries/collections/history rows
/// re-rendered it continuously; left open overnight that pegged a CPU core (Session 160, confirmed
/// by a sustained-100%-CPU microstackshot). `indexedVolumeIds` is snapshotted on the same cadence
/// for the same reason — the old pane ran `isVolumeIndexed()` once per row *per render pass*.
///
/// Version history:
///   1.0 — S-2b: initial implementation, merging `SettingsStoragePane` + `SettingsAddVolumesPane`
struct MacVolumesStorageHub: View {

    // MARK: - Batch tracking

    /// Tracks the kind and progress of a Settings-triggered bulk indexing run.
    /// Set at the start of `indexRemaining()` / `reindexAll()` / `rebuildIndex()`;
    /// cleared on completion. Drives `indexingQueueCard` visibility and header label.
    /// The old Storage pane had a third mode, `reindexAll` — `indexAllVolumes()` with no prior
    /// wipe. The hub drops it per the settled design: "Rebuild From Scratch" does everything it
    /// did and also clears rows orphaned by deleted volumes and FTS5 fragmentation, which is the
    /// actual reason anyone reached for a full re-index.
    private enum BatchKind {
        /// Iterating through unindexed volumes one by one; `current` is 1-based.
        case indexRemaining(current: Int, total: Int)
        /// Running `removeAllVolumesFromIndex()` followed by `indexAllVolumes()`.
        case rebuildAll(total: Int)
    }

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    // MARK: - Snapshot state (see the live-query hazard note above)

    /// Volumes carrying notes, collections, or summaries — never suggested for removal.
    @State private var protectedVolumeIds: Set<String> = []
    /// Most recent reading-history timestamp per volume, for the removal ordering.
    @State private var lastOpenedByVolumeId: [String: Date] = [:]
    /// Volumes present in the search index, snapshotted with the storage report.
    @State private var indexedVolumeIds: Set<String> = []
    /// The storage measurement; `nil` until the first `loadReport()` completes.
    @State private var storageReport: StorageReport? = nil
    /// The live-versus-reclaimable split of the index file, refreshed with the storage report.
    @State private var indexPages: IndexPageStatistics? = nil
    /// Free space on the volume holding the index, for the compaction precondition.
    @State private var availableBytes: Int? = nil
    /// Set while VACUUM holds its exclusive write lock.
    @State private var isCompacting = false
    /// A failed compaction's message. The Mac hub has no shared error surface, so this mirrors
    /// `spotlightRebuildError` rather than inventing one.
    @State private var compactionError: String? = nil
    /// What the last compaction reclaimed, so the row can confirm it did something.
    @State private var compactedBytes: Int? = nil


    // MARK: - Indexing state

    /// Volume being re-indexed by its own row button; drives that row's spinner.
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
    @State private var showManageStorageSheet = false
    /// Controls the GitHub download browser.
    @State private var showDownloadSheet = false
    /// Controls the full downloaded-volumes list.
    @State private var showAllVolumesSheet = false

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
            downloadedVolumesSection
            if !appState.interruptedVolumeIds.isEmpty {
                needsAttentionSection
            }
            keepingCurrentSection
            storageAndIndexSection
            // #900: one shared view, mounted by BOTH hubs. These two files are hand-maintained
            // twins, so a section written twice is two places for the same four numbers to drift.
            SemanticStorageSection()
            advancedSection
        }
        .formStyle(.grouped)
        .navigationTitle(String(localized: "settings.hub.title", defaultValue: "Volumes & Storage"))
        .task {
            await loadReport()
            // The live catalog is what makes "Check for Corrections" possible (it diffs blob SHAs
            // against `diffResult`), so it is still fetched on open. "Refresh Available List"
            // exists for asking again without reopening Settings.
            if appState.isOnline { await appState.manifestStore.refresh() }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.xml],
            allowsMultipleSelection: true
        ) { result in
            Task { await handleSideload(result) }
        }
        .sheet(isPresented: $showDownloadSheet) {
            MacDownloadVolumesSheet()
                .environment(appState)
        }
        .sheet(isPresented: $showAllVolumesSheet) {
            MacAllVolumesSheet(
                report: storageReport,
                indexedVolumeIds: indexedVolumeIds,
                protectedVolumeIds: protectedVolumeIds,
                redownloadableVolumeIds: redownloadableVolumeIds,
                lastOpenedByVolumeId: lastOpenedByVolumeId,
                reindexingVolumeId: reindexingVolumeId,
                onReindex: { volumeId in await reindexVolume(volumeId) },
                onRemove: { volumeId in await removeVolumes([volumeId]) }
            )
            .environment(appState)
        }
        .sheet(isPresented: $showManageStorageSheet) {
            MacManageStorageSheet(
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

            HStack(spacing: 10) {
                Button {
                    showDownloadSheet = true
                } label: {
                    Text(String(localized: "settings.hub.download.button",
                                defaultValue: "Download from GitHub…"))
                }
                .buttonStyle(.borderedProminent)

                Button {
                    isImporting = true
                } label: {
                    Text(String(localized: "settings.hub.sideload.button",
                                defaultValue: "Sideload XML File…"))
                }
                .buttonStyle(.bordered)

                if !appState.isOnline {
                    Label(
                        String(localized: "settings.hub.offline",
                               defaultValue: "Offline — downloads start when you reconnect."),
                        systemImage: "wifi.slash"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
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
                    Text(String(localized: "settings.hub.downloaded.empty.v2",
                                defaultValue: "No volumes on this Mac yet. Download them from GitHub, or add an XML file you already have."))
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
                        Button {
                            showAllVolumesSheet = true
                        } label: {
                        HStack {
                            Text(String(localized: "settings.hub.downloaded.showAll",
                                        defaultValue: "Show all \(report.perVolume.count)"))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
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
                        ProgressView().controlSize(.small)
                    } else {
                        Button(String(localized: "settings.hub.interrupted.reindex",
                                      defaultValue: "Re-index")) {
                            reindexInterrupted(volumeId: volumeId)
                        }
                        .buttonStyle(.bordered)
                        .disabled(actionsBusy)
                    }
                }
            }

            if interrupted.count > 1 {
                Button {
                    reindexAllInterrupted(interrupted)
                } label: {
                    if reindexingInterruptedId == "all" {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
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
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Keeping Current

    @ViewBuilder
    private var keepingCurrentSection: some View {
        Section {
            HStack(spacing: 10) {
                Button {
                    Task { await checkForUpdates() }
                } label: {
                    if isCheckingForUpdates {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text(String(localized: "settings.hub.corrections.checking",
                                        defaultValue: "Checking…"))
                        }
                    } else {
                        Text(String(localized: "settings.hub.corrections.button",
                                    defaultValue: "Check for Corrections"))
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isCheckingForUpdates
                          || (storageReport?.perVolume.isEmpty ?? true)
                          || appState.manifestStore.diffResult == nil)
                .controlHelp(
                    String(localized: "settings.hub.corrections.a11y",
                           defaultValue: "Check downloaded volumes for upstream corrections"),
                    detail: String(localized: "settings.hub.corrections.help",
                                   defaultValue: "Compares each downloaded volume against the FRUS repository and lists any that changed since you downloaded them"),
                    systemImage: "arrow.triangle.2.circlepath"
                )

                Button {
                    Task { await refreshCatalog() }
                } label: {
                    if isRefreshingCatalog {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text(String(localized: "settings.hub.catalog.refreshing",
                                        defaultValue: "Refreshing…"))
                        }
                    } else {
                        Text(String(localized: "settings.hub.catalog.button",
                                    defaultValue: "Refresh Available List"))
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isRefreshingCatalog || !appState.isOnline)
                .controlHelp(
                    String(localized: "settings.hub.catalog.a11y",
                           defaultValue: "Look for newly published volumes"),
                    detail: String(localized: "settings.hub.catalog.help",
                                   defaultValue: "Re-reads the FRUS repository's volume list so newly published volumes appear in the download browser"),
                    systemImage: "arrow.clockwise"
                )
            }

            if !updatableVolumes.isEmpty {
                ForEach(updatableVolumes) { updatable in
                    SettingsNavRow(label: updatable.entry.title, detail: updatable.entry.volumeId)
                        .overlay(alignment: .trailing) {
                            Button(String(localized: "settings.hub.corrections.update",
                                          defaultValue: "Update")) {
                                Task { await updateVolume(updatable) }
                            }
                            .buttonStyle(.bordered)
                        }
                }
                Button {
                    Task { await updateAllVolumes() }
                } label: {
                    Text(String(localized: "settings.hub.corrections.updateAll",
                                defaultValue: "Update All"))
                }
                .buttonStyle(.borderedProminent)
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
                .font(.caption)
                .foregroundStyle(.secondary)
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

            HStack(spacing: 10) {
                Button {
                    showManageStorageSheet = true
                } label: {
                    Text(String(localized: "settings.hub.freeUp.button",
                                defaultValue: "Free Up Space…"))
                }
                .buttonStyle(.bordered)
                .disabled(storageReport == nil || removalPlan.isEmpty)
                .controlHelp(
                    String(localized: "settings.hub.freeUp.a11y",
                           defaultValue: "Review removable volumes"),
                    detail: String(localized: "settings.hub.freeUp.help",
                                   defaultValue: "Lists downloaded volumes with no attached notes, collections, or summaries so you can remove them"),
                    systemImage: "trash"
                )

                Button {
                    bulkIndexingFailureCount = nil
                    Task { await indexRemaining() }
                } label: {
                    Text(String(localized: "settings.hub.indexRemaining.button",
                                defaultValue: "Index Remaining"))
                }
                .buttonStyle(.bordered)
                .disabled(actionsBusy)
                .controlHelp(
                    String(localized: "settings.hub.indexRemaining.a11y",
                           defaultValue: "Index volumes that have not been indexed yet"),
                    detail: String(localized: "settings.hub.indexRemaining.help.v2",
                                   defaultValue: "Indexes only the volumes that still need it, and leaves the rest untouched"),
                    systemImage: "plus.circle"
                )

                Button(role: .destructive) {
                    showRebuildConfirmation = true
                } label: {
                    Text(String(localized: "settings.hub.rebuild.button",
                                defaultValue: "Rebuild From Scratch"))
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(actionsBusy)
                .controlHelp(
                    String(localized: "settings.hub.rebuild.a11y",
                           defaultValue: "Delete the search index and rebuild it"),
                    detail: String(localized: "settings.hub.rebuild.help.v2",
                                   defaultValue: "Deletes what the app has built for searching and builds it again from every downloaded volume. Use this if search results look wrong, or if leftovers remain from volumes you deleted."),
                    systemImage: "trash.circle"
                )
            }

            if let failures = bulkIndexingFailureCount, failures > 0 {
                SettingsStatusRow(
                    label: String(localized: "settings.hub.indexFailures.v2",
                                  defaultValue: "\(HubCopy.volumes(failures)) could not be indexed"),
                    detail: String(localized: "settings.hub.indexFailures.detail",
                                   defaultValue: "Check Console.app (subsystem: bottsywattsy.FRUS-Explorer) for the reason."),
                    state: .error
                )
            }
        } header: {
            Text(String(localized: "settings.hub.storageIndex.header",
                        defaultValue: "Storage & Index"))
        } footer: {
            Text(String(localized: "settings.hub.storageIndex.footer",
                        defaultValue: "Notes, highlights, and tags are never affected. For reference: the full FRUS corpus is roughly 3.4 GB of XML plus 9–10 GB of search index."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Advanced

    @ViewBuilder
    private var advancedSection: some View {
        Section(String(localized: "settings.hub.advanced.header", defaultValue: "Advanced")) {
            IndexHealthView(actionsDisabled: actionsBusy)

            HStack {
                Text(String(localized: "settings.hub.spotlight.label",
                            defaultValue: "Spotlight Index"))
                Spacer()
                Button {
                    Task { await runRebuildSpotlightIndex() }
                } label: {
                    if spotlightRebuildRunning {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text(String(localized: "settings.hub.spotlight.running",
                                        defaultValue: "Rebuilding…"))
                        }
                    } else {
                        Text(String(localized: "settings.hub.spotlight.button",
                                    defaultValue: "Rebuild"))
                    }
                }
                .buttonStyle(.bordered)
                .disabled(actionsBusy || spotlightRebuildRunning || appState.indexingPipeline == nil)
                .controlHelp(
                    String(localized: "settings.hub.spotlight.a11y",
                           defaultValue: "Rebuild the system Spotlight index"),
                    detail: String(localized: "settings.hub.spotlight.help.v2",
                                   defaultValue: "Rebuilds what Spotlight knows about your documents. Quicker than a full reindex, because it reuses text the app has already read."),
                    systemImage: "magnifyingglass"
                )
            }

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

            Picker(selection: $concurrentDownloadLimit) {
                ForEach([1, 2, 3, 4, 6], id: \.self) { n in
                    Text("\(n)").tag(n)
                }
            } label: {
                SettingsNavRow(
                    label: String(localized: "settings.hub.concurrency.label",
                                  defaultValue: "Concurrent downloads"),
                    detail: String(localized: "settings.hub.concurrency.detail",
                                   defaultValue: "How many volumes download at the same time.")
                )
            }
            .onChange(of: concurrentDownloadLimit) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: SettingsKeys.concurrentDownloadLimit)
                if let dm = appState.downloadManager {
                    Task { await dm.setConcurrencyLimit(newValue) }
                }
            }
        }
    }

    // MARK: - Inline Queue Progress Card

    /// Live batch progress, shown while `settingsBatch` is non-nil or the app is indexing.
    ///
    /// Shows the batch position and ETA, the current volume, and its document throughput.
    @ViewBuilder
    private var indexingQueueCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
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
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.mini)
                        Text(String(localized: "settings.storage.indexing.preparing",
                                    defaultValue: "Preparing…"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FRUSTheme.settingsCardFill,
                    in: RoundedRectangle(cornerRadius: FRUSTheme.settingsCardCornerRadius))
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
                                          summaryBytes: report.totalSummariesBytes)
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

    /// What Free Up Space may offer, and in what order. Shared with iOS so the two platforms
    /// cannot drift into offering different volumes (`StorageRemovalPlan`).
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
            compactionError = error.localizedDescription
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
        storageReport = try? await dm.storageReport(indexDirectory: appState.indexDirectory)
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

    /// Imports the chosen XML files through the same `SideloadValidator` iOS uses.
    ///
    /// The macOS path used to be a bare `FileManager.copyItem` with **no validation at all** — any
    /// XML file was accepted, and one whose name matched a downloaded volume silently replaced it.
    /// It also never called `refreshReadOnlyStores()`, so a sideloaded volume's cross-references
    /// and person mentions stayed invisible to analytics until relaunch (#275). Routing both
    /// platforms through the validator fixes all three at once; multi-file selection is kept by
    /// running it per file and reporting the tally.
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
    /// Runs only on explicit user request — never automatically at launch.
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
                    print("[MacVolumesStorageHub] Re-index interrupted volume \(volumeId) failed: \(error)")
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
    /// (#275) and the report is re-measured. The sheet used to carry its own copy of this and
    /// had never called `refreshReadOnlyStores()` at all.
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

// MARK: - MacAllVolumesSheet

/// The full downloaded-volume list, behind the hub's "Show all N" door (S-2b).
///
/// The hub shows the first few volumes inline; a full corpus download puts 550-odd rows behind
/// this sheet rather than in the form, where they would bury everything below them.
///
/// A sheet rather than a `NavigationStack` push: the macOS Settings window carries no navigation
/// chrome of its own, and this pane's sibling (Free Up Space) has always been a sheet. The iOS hub
/// (S-2c) pushes, which is that platform's equivalent gesture.
///
/// Version history:
///   1.0 — S-2b: initial implementation, from `SettingsStoragePane.volumeTable`
private struct MacAllVolumesSheet: View {

    /// The storage measurement, or `nil` while it is still being taken.
    let report: StorageReport?
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
    @Environment(\.dismiss) private var dismiss

    @State private var filter = ""
    @State private var pendingRemoval: String? = nil

    private var entries: [VolumeStorageEntry] {
        let all = report?.perVolume ?? []
        let needle = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return all }
        return all.filter { entry in
            let title = appState.manifestStore.entry(forVolumeId: entry.volumeId)?.title ?? ""
            return "\(entry.volumeId)\n\(title)".range(
                of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "settings.hub.allVolumes.title",
                                defaultValue: "Volumes on This Mac"))
                        .font(.headline)
                    Text(String(localized: "settings.hub.allVolumes.subtitle",
                                defaultValue: "\(HubCopy.volumes(report?.perVolume.count ?? 0)) downloaded."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(String(localized: "settings.hub.done", defaultValue: "Done")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(20)

            Divider()

            TextField(String(localized: "settings.hub.allVolumes.filter",
                             defaultValue: "Filter by title or volume ID"),
                      text: $filter)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

            if entries.isEmpty {
                ContentUnavailableView(
                    String(localized: "settings.hub.allVolumes.none", defaultValue: "No Matches"),
                    systemImage: "magnifyingglass",
                    description: Text(String(localized: "settings.hub.allVolumes.none.detail",
                                             defaultValue: "No downloaded volume matches that filter."))
                )
            } else {
                List(entries, id: \.volumeId) { entry in
                    row(entry)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 560, minHeight: 460)
        .alert(
            String(localized: "settings.hub.remove.title", defaultValue: "Remove this volume?"),
            isPresented: Binding(get: { pendingRemoval != nil },
                                 set: { if !$0 { pendingRemoval = nil } })
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
                Text(String(localized: "settings.hub.remove.message.sideloaded",
                            defaultValue: "The XML file and its search-index rows are deleted from this Mac. Your notes, highlights, tags, and summaries for it are kept. **This volume was side-loaded, so the app cannot download it again** — if you no longer have the file, this cannot be undone."))
            } else {
                Text(String(localized: "settings.hub.remove.message",
                            defaultValue: "The XML file and its search-index rows are deleted from this Mac. Your notes, highlights, tags, and summaries for it are kept, and the volume can be downloaded again."))
            }
        }
    }

    @ViewBuilder
    private func row(_ entry: VolumeStorageEntry) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(appState.manifestStore.entry(forVolumeId: entry.volumeId)?.title
                         ?? entry.volumeId)
                        .lineLimit(1)
                    if protectedVolumeIds.contains(entry.volumeId) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .controlHelp(
                                String(localized: "settings.hub.protected.a11y",
                                       defaultValue: "Has attached research data"),
                                detail: String(localized: "settings.hub.protected.help",
                                               defaultValue: "This volume carries notes, collections, or summaries and is never suggested for automatic removal"),
                                systemImage: "lock.fill"
                            )
                    }
                }
                Text(statusLine(entry))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if reindexingVolumeId == entry.volumeId {
                ProgressView().controlSize(.small)
            } else {
                Button(String(localized: "settings.hub.allVolumes.reindex",
                              defaultValue: "Re-index")) {
                    Task { await onReindex(entry.volumeId) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(reindexingVolumeId != nil)
            }

            Button(String(localized: "settings.hub.allVolumes.remove", defaultValue: "Remove")) {
                pendingRemoval = entry.volumeId
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.red)
            .disabled(reindexingVolumeId != nil)
        }
        .padding(.vertical, 4)
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

// MARK: - MacDownloadVolumesSheet

/// The GitHub download browser, behind the hub's "Download from GitHub…" door (S-2b).
///
/// The 552-row catalogue leaves the settings form entirely: choosing what to download is its own
/// task, and inlining it made the hub's other five sections unreachable without scrolling past a
/// list of every volume ever published. A filter field leads, because picking one volume out of
/// 552 by scrolling a disclosure tree is not a real interaction.
///
/// Version history:
///   1.0 — S-2b: initial implementation, from `SettingsAddVolumesPane.downloadSection`
private struct MacDownloadVolumesSheet: View {

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    /// What the user is choosing to download.
    private enum ScopeChoice { case corpus, subseries, volume }

    @State private var scopeChoice: ScopeChoice = .corpus
    @State private var selectedSubseries: Set<String> = []
    @State private var selectedVolumeIds: Set<String> = []
    @State private var filter = ""
    @State private var isEnqueuing = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "settings.hub.browse.title",
                                defaultValue: "Download from GitHub"))
                        .font(.headline)
                    Text(String(localized: "settings.hub.browse.subtitle",
                                defaultValue: "Volumes are fetched from the Office of the Historian's public FRUS repository."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(String(localized: "settings.hub.rebuild.cancel", defaultValue: "Cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(20)

            Divider()

            VStack(spacing: 6) {
                scopeCard(isSelected: scopeChoice == .corpus,
                          title: String(localized: "settings.hub.browse.corpus",
                                        defaultValue: "Entire Corpus"),
                          detail: corpusDetail) {
                    scopeChoice = .corpus; selectedSubseries = []; selectedVolumeIds = []
                }
                scopeCard(isSelected: scopeChoice == .subseries,
                          title: String(localized: "settings.hub.browse.subseries",
                                        defaultValue: "One or More Subseries"),
                          detail: String(localized: "settings.hub.browse.subseries.detail",
                                         defaultValue: "Choose one or more decades or diplomatic eras.")) {
                    scopeChoice = .subseries; selectedVolumeIds = []
                }
                scopeCard(isSelected: scopeChoice == .volume,
                          title: String(localized: "settings.hub.browse.volumes",
                                        defaultValue: "Individual Volumes"),
                          detail: String(localized: "settings.hub.browse.volumes.detail",
                                         defaultValue: "Select specific volumes from any subseries.")) {
                    scopeChoice = .volume; selectedSubseries = []
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            if scopeChoice != .corpus {
                TextField(String(localized: "settings.hub.browse.filter",
                                 defaultValue: "Filter by title, volume ID, or subseries"),
                          text: $filter)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
            }

            Divider()

            switch scopeChoice {
            case .corpus:
                ContentUnavailableView(
                    String(localized: "settings.hub.browse.corpus.title",
                           defaultValue: "The Whole Corpus"),
                    systemImage: "square.stack.3d.up",
                    description: Text(String(localized: "settings.hub.browse.corpus.body",
                                             defaultValue: "Every published volume will be queued. Downloads run in the background and resume across launches; you can start reading as soon as the first volume lands."))
                )
            case .subseries:
                subseriesList
            case .volume:
                volumeList
            }

            Divider()

            HStack(spacing: 12) {
                Text(selectionSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if !appState.isOnline {
                    Label(String(localized: "settings.hub.offline",
                                 defaultValue: "Offline — downloads start when you reconnect."),
                          systemImage: "wifi.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    Task { await enqueueSelected() }
                } label: {
                    if isEnqueuing {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(String(localized: "settings.hub.browse.download",
                                    defaultValue: "Download"))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canDownload || isEnqueuing)
            }
            .padding(20)
        }
        .frame(minWidth: 620, minHeight: 560)
    }

    // MARK: Scope cards

    @ViewBuilder
    private func scopeCard(isSelected: Bool,
                           title: String,
                           detail: String,
                           onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3),
                            lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        // A5: expose the chosen scope as a trait, not just the radio-symbol swap.
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Lists

    private var subseriesList: some View {
        List(filteredSubseries, id: \.self) { sub in
            Button {
                if selectedSubseries.contains(sub) {
                    selectedSubseries.remove(sub)
                } else {
                    selectedSubseries.insert(sub)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: selectedSubseries.contains(sub) ? "checkmark.square.fill" : "square")
                        .foregroundStyle(selectedSubseries.contains(sub) ? Color.accentColor : Color.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(sub).foregroundStyle(.primary)
                        let count = allVolumes.filter { $0.subseries == sub }.count
                        Text(HubCopy.volumes(count))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selectedSubseries.contains(sub) ? .isSelected : [])
        }
        .listStyle(.inset)
    }

    private var volumeList: some View {
        List(filteredVolumes) { vol in
            Button {
                if selectedVolumeIds.contains(vol.volumeId) {
                    selectedVolumeIds.remove(vol.volumeId)
                } else {
                    selectedVolumeIds.insert(vol.volumeId)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: selectedVolumeIds.contains(vol.volumeId) ? "checkmark.square.fill" : "square")
                        .foregroundStyle(selectedVolumeIds.contains(vol.volumeId) ? Color.accentColor : Color.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(vol.title)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text("\(vol.subseries) · \(vol.volumeId)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selectedVolumeIds.contains(vol.volumeId) ? .isSelected : [])
        }
        .listStyle(.inset)
    }

    // MARK: Derived

    /// The catalogue, minus anything too small to be a real volume.
    ///
    /// The size floor guards against placeholder or stub XML appearing in a *live* manifest
    /// refresh; measured against the bundled manifest it currently excludes nothing (0 of 552
    /// entries fall under it).
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

    private var corpusDetail: String {
        let bytes = allVolumes.reduce(0) { $0 + $1.sizeBytes }
        let xml = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
        return String(localized: "settings.hub.browse.corpus.detail",
                      defaultValue: "\(HubCopy.volumes(allVolumes.count)) · \(xml) of XML, plus roughly 2.8× that in search index.")
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

// MARK: - MacManageStorageSheet

/// The Free Up Space sheet, opened from the hub's Storage & Index section (S-2b).
///
/// Renders `StorageRemovalPlan` — which volumes are eligible and in what order is decided there,
/// shared with the iOS sheet, so the two platforms cannot drift into offering different volumes.
/// Removal itself is the hub's `removeVolumes`, again shared, so both sheets get the VACUUM and
/// the read-only-store reopen (#275) on the same terms.
///
/// ## Index size estimates
/// Per-volume index contribution is estimated at **2.8×** the XML file size
/// (`StorageReport.indexOverheadFactor`) — the cross-platform mean measured against a full
/// 552-volume download; individual volumes range from roughly 2.5× (short) to 3.0× (long).
/// The UI prefixes every estimate with "~" and explains the methodology.
///
/// Version history:
///   1.0 — Session 130: initial implementation as `ManageStorageSheet`
///   1.1 — S-2a: corrected a doc claim that the estimate was "40% of the XML file size"; the
///          constant has been 2.8 and the user-visible banner has said 2.8× since it shipped
///   1.2 — S-2b: moved out of `FRUSSettingsView.swift` with the hub; removals now reopen the
///          read-only stores (#275), which the sheet had never done
///   1.3 — S-2c: candidate selection, ordering, and the size estimate move to the shared
///          `StorageRemovalPlan`; removal moves to the hub. The sheet is now only the rendering.
private struct MacManageStorageSheet: View {

    /// What may be removed, and in what order.
    let plan: StorageRemovalPlan
    /// Removes the chosen volumes; the host re-measures afterwards.
    let onRemove: ([String]) async -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Set<String> = []
    @State private var isRemoving = false
    /// Whether the "Remove N volumes" confirmation is up.
    ///
    /// This sheet used to delete on the first click, with no confirmation of any kind — the
    /// button's action was `Task { await performRemoval() }`. iOS has always asked first, using
    /// the two keys below; the Mac now asks the same question in the same words.
    @State private var showConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "settings.hub.freeUp.title",
                                defaultValue: "Free Up Space"))
                        .font(.headline)
                    Text(String(localized: "settings.hub.freeUp.subtitle",
                                defaultValue: "Select volumes to remove. Only volumes with no attached notes, collections, or summaries are shown."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(String(localized: "settings.hub.done", defaultValue: "Done")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(isRemoving)
            }
            .padding(20)

            Divider()

            if plan.isEmpty {
                ContentUnavailableView(
                    String(localized: "settings.hub.freeUp.none",
                           defaultValue: "No Removable Volumes"),
                    systemImage: "lock.shield",
                    description: Text(String(localized: "settings.hub.freeUp.none.detail",
                                             defaultValue: "Every downloaded volume has attached notes, collections, or summaries. Remove those individually from \"Show all\" in Volumes & Storage."))
                )
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "settings.hub.freeUp.estimateNote",
                                defaultValue: "Each size is the XML file plus an estimated 2.8× for its share of the search index. That ratio comes from the full corpus: about 9–10 GB of index for about 3.4 GB of XML. Per volume the overhead runs from roughly 2.5× to 3×, so treat these sizes as approximate."))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.06))

                List {
                    ForEach(plan.candidates) { candidate in
                        candidateRow(candidate)
                    }
                }
                .listStyle(.plain)
            }

            if !plan.isEmpty {
                Divider()
                HStack(spacing: 12) {
                    if selected.isEmpty {
                        Text(String(localized: "settings.hub.freeUp.selectPrompt",
                                    defaultValue: "Select volumes to see estimated recovery"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(String(localized: "settings.hub.freeUp.recovery",
                                        defaultValue: "~\(ByteCountFormatter.string(fromByteCount: Int64(plan.estimatedRecovery(for: selected)), countStyle: .file)) estimated recovery"))
                                .font(.callout)
                                .fontWeight(.medium)
                            Text(String(localized: "settings.hub.freeUp.recovery.detail",
                                        defaultValue: "Actual freed space may differ; the index shrinks after removal."))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                    Button {
                        showConfirmation = true
                    } label: {
                        if isRemoving {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(String(localized: "settings.hub.freeUp.remove",
                                        defaultValue: "Remove \(HubCopy.volumes(selected.count))"))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(selected.isEmpty || isRemoving)
                }
                .padding(20)
            }
        }
        .frame(minWidth: 520, minHeight: 420)
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
        .overlay {
            if isRemoving {
                ZStack {
                    Color.black.opacity(0.2)
                    VStack(spacing: 10) {
                        ProgressView()
                        Text(String(localized: "settings.hub.freeUp.removing",
                                    defaultValue: "Removing volumes and compacting index…"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    @ViewBuilder
    private func candidateRow(_ candidate: StorageRemovalPlan.Candidate) -> some View {
        let volumeId = candidate.volumeId
        let isSelected = selected.contains(volumeId)
        let title = appState.manifestStore.entry(forVolumeId: volumeId)?.title

        Button {
            if isSelected { selected.remove(volumeId) } else { selected.insert(volumeId) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title ?? volumeId)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(volumeId)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text("~\(ByteCountFormatter.string(fromByteCount: Int64(candidate.estimatedBytes), countStyle: .file))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let date = candidate.lastOpened {
                        Text(String(localized: "settings.hub.freeUp.opened",
                                    defaultValue: "Opened \(date.formatted(.relative(presentation: .named)))"))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text(String(localized: "settings.hub.freeUp.neverOpened",
                                    defaultValue: "Never opened"))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // A5: expose selection as a trait, not just the symbol swap.
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .padding(.vertical, 4)
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
