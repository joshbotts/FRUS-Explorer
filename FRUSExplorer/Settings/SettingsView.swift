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
/// | User tags | `UserTagsView` |
/// | Projects | `ProjectsSettingsView` |
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
///   2.3 — Session 118: Reindex row removed; Storage renamed to Storage & Index; Reindex All
///          controls absorbed into StorageManagementView; Summarization Prompts → Summarization
///   2.4 — Session 153: Projects row added to Research section (ProjectsSettingsView), closing
///          the iOS gap where projects could be created but never renamed/merged/deleted;
///          delete/merge mutations shared with macOS SettingsProjectsPane via ProjectAdminService
///   2.5 — Session 154: Data section added with "Export Research Data…" row
///          (ResearchDataExportView) — JSON + per-note Markdown export via ShareLink
struct SettingsView: View {

    #if !os(iOS)
    @Environment(\.dismiss) private var dismiss
    #endif

    @AppStorage("researchSessionLoggingEnabled") private var loggingEnabled = true
    /// Device-local master toggle for optional cross-device settings sync.
    @AppStorage(SettingsSyncCoordinator.enabledKey) private var syncSettingsEnabled = false
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        NavigationStack {
            Form {
                // iCloud sync status — visible on iOS where there is no macOS status bar.
                // Shows container init result and the most recent sync event outcome.
                Section {
                    iCloudSyncStatusRow
                    Toggle(isOn: $syncSettingsEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "settings.sync.toggle",
                                        defaultValue: "Sync Settings Across Devices"))
                            Text(String(localized: "settings.sync.toggle.detail",
                                        defaultValue: "Word-cloud filters & stop lists, citation style, default document mode, and research logging."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(!appState.cloudKitSyncEnabled)
                    .onChange(of: syncSettingsEnabled) { _, newValue in
                        appState.settingsSync?.handleEnabledChange(newValue)
                    }
                    if !appState.cloudKitSyncEnabled {
                        Text(String(localized: "settings.sync.unavailable",
                                    defaultValue: "Settings sync needs iCloud. Sign in to iCloud and enable it for FRUS Explorer to turn this on."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(String(localized: "settings.section.icloud", defaultValue: "iCloud Sync"))
                } footer: {
                    Text(String(localized: "settings.sync.footer",
                                defaultValue: "When on, this device shares the settings above with your other devices that also have this enabled. Turning it on adopts your existing iCloud settings; leave it off to keep this device's settings separate."))
                }

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
                                         defaultValue: "Storage & Index")) {
                        StorageManagementView()
                    }
                    NavigationLink(String(localized: "settings.row.sideload",
                                         defaultValue: "Sideload Volume")) {
                        SideloadView()
                    }
                }

                Section(String(localized: "settings.section.research",
                               defaultValue: "Research")) {
                    NavigationLink(String(localized: "settings.row.scopes",
                                         defaultValue: "Volume Scopes")) {
                        CustomScopesView()
                    }
                    NavigationLink(String(localized: "settings.row.tags",
                                         defaultValue: "User Tags")) {
                        UserTagsView()
                    }
                    NavigationLink(String(localized: "settings.row.projects",
                                         defaultValue: "Projects")) {
                        ProjectsSettingsView()
                    }
                    NavigationLink(String(localized: "settings.row.summarization",
                                         defaultValue: "Summarization")) {
                        SummarizationPromptsSettingsView()
                    }
                    NavigationLink(String(localized: "settings.row.wordCloud",
                                         defaultValue: "Word Cloud")) {
                        WordCloudSettingsView()
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
                    NavigationLink(String(localized: "settings.row.zotero",
                                         defaultValue: "Zotero")) {
                        ZoteroIntegrationView()
                    }
                }

                Section(String(localized: "settings.section.data",
                               defaultValue: "Data")) {
                    NavigationLink(String(localized: "settings.row.exportData",
                                         defaultValue: "Export Research Data…")) {
                        ResearchDataExportView()
                    }
                    NavigationLink(String(localized: "settings.row.syncDiagnostics",
                                         defaultValue: "Sync Diagnostics")) {
                        SyncDiagnosticsView()
                    }
                }

                #if os(iOS) && DEBUG
                Section("Diagnostics") {
                    NavigationLink("Summarization Probe") {
                        SummarizationProbeView()
                    }
                }
                #endif

                Section {
                    NavigationLink(String(localized: "settings.row.reset",
                                         defaultValue: "Reset App")) {
                        ResetView()
                    }
                    .foregroundStyle(.red)
                }

                #if os(iOS)
                Section {
                    Button(String(localized: "settings.row.researchGuide",
                                  defaultValue: "FRUS Research Guide")) {
                        appState.showResearchGuide = true
                    }
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
            #if os(iOS)
            // Standalone "Research Guide" — the same five educational pages
            // shown during first-index onboarding, reachable here on demand
            // (presented as a sheet rather than pushed, since it manages its
            // own paging/navigation chrome via `ResearchGuideView`).
            .sheet(isPresented: $appState.showResearchGuide) {
                ResearchGuideView()
                    .environment(appState)
            }
            #endif
        }
        #if os(macOS)
        // Provides stable minimum dimensions for the settings sheet on macOS so that
        // NavigationLink destinations inherit a proper sized container and render correctly.
        .frame(minWidth: 500, minHeight: 440)
        #endif
    }

    // MARK: - iCloud Sync Status Row
    //
    // Each status case collapses the indicator + detail into a single Form row
    // (VStack inside one cell) to avoid the tall multi-row layout that appeared
    // when the status label and its explanation text occupied separate cells.

    @ViewBuilder
    private var iCloudSyncStatusRow: some View {
        if !appState.cloudKitSyncEnabled {
            // Append the actual CloudKit diagnostic (domain + error code name +
            // description, e.g. "CKErrorDomain serverRejectedRequest: …") below the
            // general guidance whenever `AppState.cloudKitInitError` has one — so
            // users and testers can see exactly *why* initialisation failed, not just
            // that it did. Previously this was a hardcoded "check console for details"
            // placeholder with no code visible anywhere in the running app.
            let guidance = String(localized: "settings.icloud.localOnly.detail",
                                  defaultValue: "iCloud sync is unavailable. Notes, tags, and collections won't sync across devices. Check that you are signed in to iCloud in Settings and that FRUS Explorer has iCloud access.")
            // Computed via an immediately-invoked closure rather than an `if`/`else`
            // directly in this @ViewBuilder body — a plain `if let … else …` whose
            // branches only assign to `detail` makes the result-builder transform try
            // to coerce each branch's `()` result to `View`, producing "Type '()'
            // cannot conform to 'View'". The closure keeps it a normal expression the
            // builder evaluates once, outside the View-producing chain.
            let detail: String = {
                guard let initError = appState.cloudKitInitError else { return guidance }
                return "\(guidance)\n\n\(String(localized: "settings.icloud.localOnly.diagnostic.label", defaultValue: "Diagnostic")): \(initError)"
            }()
            iCloudStatusCell(
                label: String(localized: "settings.icloud.localOnly", defaultValue: "Local Only"),
                systemImage: "icloud.slash",
                color: .orange,
                detail: detail
            )
        } else {
            switch appState.cloudKitSyncState {
            case .unknown:
                LabeledContent(
                    String(localized: "settings.icloud.status", defaultValue: "Status")
                ) {
                    Label(
                        String(localized: "settings.icloud.enabled", defaultValue: "iCloud Sync Enabled"),
                        systemImage: "checkmark.icloud"
                    )
                    .foregroundStyle(.secondary)
                }

            case .syncing:
                LabeledContent(
                    String(localized: "settings.icloud.status", defaultValue: "Status")
                ) {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.75, anchor: .center)
                        Text(String(localized: "settings.icloud.syncing", defaultValue: "Syncing…"))
                            .foregroundStyle(.secondary)
                    }
                }

            case .succeeded(let date):
                LabeledContent(
                    String(localized: "settings.icloud.status", defaultValue: "Status")
                ) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Label(
                            String(localized: "settings.icloud.synced", defaultValue: "Synced"),
                            systemImage: "checkmark.icloud"
                        )
                        .foregroundStyle(.green)
                        Text(date, style: .relative)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

            case .failed(let message):
                iCloudStatusCell(
                    label: String(localized: "settings.icloud.error", defaultValue: "Sync Error"),
                    systemImage: "exclamationmark.icloud",
                    color: .orange,
                    detail: message
                )
            }

            // Zone-missing warning (silent failure — never reported by sync events)
            if appState.cloudKitZoneVerified == false {
                iCloudStatusCell(
                    label: String(localized: "settings.icloud.zoneMissing", defaultValue: "Private Zone Missing"),
                    systemImage: "exclamationmark.icloud.fill",
                    color: .red,
                    detail: String(localized: "settings.icloud.zoneMissing.detail",
                                   defaultValue: "The iCloud sync zone is missing. Data cannot upload or download until it is recreated. Force-quit and relaunch the app, or tap Reset iCloud Sync below.")
                )
            }

            // Account status issues
            if let status = appState.cloudKitAccountStatus, status != .available {
                iCloudStatusCell(
                    label: String(localized: "settings.icloud.accountIssue", defaultValue: "Account Issue"),
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    color: .orange,
                    detail: AppState.accountStatusDescription(status)
                )
            }
        }
    }

    /// Compact single-row iCloud status indicator with a status label and inline detail text.
    private func iCloudStatusCell(
        label: String,
        systemImage: String,
        color: Color,
        detail: String
    ) -> some View {
        LabeledContent(
            String(localized: "settings.icloud.status", defaultValue: "Status")
        ) {
            VStack(alignment: .trailing, spacing: 2) {
                Label(label, systemImage: systemImage)
                    .foregroundStyle(color)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
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
/// 4. **Updates** — "Check for Updates" diffs downloaded volumes' git blob SHAs
///    against the live manifest; lists changed volumes with per-volume "Update" and
///    "Update All" (force re-download + automatic re-index, preserving user data).
/// 5. **Settings** — concurrent downloads picker; iOS also gets an "Allow Cellular
///    Downloads" toggle (`SettingsKeys.allowCellularDownloads`).
/// 6. **Check for New Volumes** — button that refreshes the live manifest.
///
/// Version history:
///   1.0 — Session 117: merged from VolumeManagementView (Session 49, 51, 70) and
///          DownloadManagerSettingsView (Session 49, 67)
///   1.1 — Session 154: added iOS-only "Allow Cellular Downloads" toggle to the
///          Settings section, applied per-request via `DownloadManager.processQueue()`
///   1.2 — Session 154: added "Updates" section — `VolumeUpdateChecker` detects
///          upstream corrections to downloaded volumes via git blob SHA comparison
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

    // MARK: Cellular download policy (Session 154, iOS only)

    #if os(iOS)
    @AppStorage(SettingsKeys.allowCellularDownloads) private var allowCellularDownloads: Bool = true
    #endif

    // MARK: Update detection (Session 154)

    @State private var updatableVolumes: [UpdatableVolume] = []
    @State private var isCheckingForUpdates: Bool = false
    @State private var hasCheckedForUpdates: Bool = false

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

            // 4. Updates — check downloaded volumes for upstream corrections.
            Section(
                header: Text(String(localized: "settings.volumes.updates.header",
                                     defaultValue: "Updates")),
                footer: Text(String(localized: "settings.volumes.updates.footer",
                                     defaultValue: "Checks downloaded volumes against the FRUS repository for upstream corrections. Updating re-downloads and re-indexes the volume; your notes, highlights, tags, and summaries are preserved."))
            ) {
                updatesSection
            }

            // 5. Settings.
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
                    // Apply immediately — a higher limit starts pending downloads
                    // right away; a lower one applies as transfers finish.
                    if let dm = appState.downloadManager {
                        Task { await dm.setConcurrencyLimit(newValue) }
                    }
                    #if DEBUG
                    print("[Settings] Concurrent download limit set to \(newValue)")
                    #endif
                }
                .accessibilityLabel(
                    String(localized: "settings.volumes.concurrentLimit.a11y",
                           defaultValue: "Concurrent download limit")
                )
                Text(String(localized: "settings.volumes.concurrentLimit.note",
                            defaultValue: "How many volumes download at the same time."))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                #if os(iOS)
                Toggle(
                    String(localized: "settings.volumes.allowCellular.label",
                           defaultValue: "Allow Cellular Downloads"),
                    isOn: $allowCellularDownloads
                )
                .accessibilityHint(
                    String(localized: "settings.volumes.allowCellular.a11y",
                           defaultValue: "When off, volume downloads only proceed over Wi-Fi")
                )
                Text(String(localized: "settings.volumes.allowCellular.note",
                            defaultValue: "Applies to downloads started after this change. Volume files are large; Wi-Fi is recommended."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #endif
            }

            // 6. Check for New Volumes.
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
    private var updatesSection: some View {
        if !updatableVolumes.isEmpty {
            ForEach(updatableVolumes) { updatable in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(updatable.entry.title)
                            .font(.callout)
                            .lineLimit(2)
                        Text(updatable.entry.volumeId)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(String(localized: "settings.volumes.updates.update",
                                  defaultValue: "Update")) {
                        Task { await updateVolume(updatable) }
                    }
                    .font(.callout)
                    .buttonStyle(.borderless)
                    .accessibilityLabel(
                        String(localized: "settings.volumes.updates.update.a11y",
                               defaultValue: "Update \(updatable.entry.title)")
                    )
                }
            }

            Button {
                Task { await updateAllVolumes() }
            } label: {
                Label(
                    String(localized: "settings.volumes.updates.updateAll",
                           defaultValue: "Update All"),
                    systemImage: "arrow.down.circle"
                )
            }
            .accessibilityLabel(
                String(localized: "settings.volumes.updates.updateAll.a11y",
                       defaultValue: "Update all volumes with available corrections")
            )
        } else if hasCheckedForUpdates && !isCheckingForUpdates {
            Text(String(localized: "settings.volumes.updates.upToDate",
                        defaultValue: "All downloaded volumes are up to date."))
                .foregroundStyle(.secondary)
                .font(.callout)
        }

        Button {
            Task { await checkForUpdates() }
        } label: {
            if isCheckingForUpdates {
                HStack {
                    ProgressView()
                    Text(String(localized: "settings.volumes.updates.checking",
                                defaultValue: "Checking for Updates…"))
                }
            } else {
                Label(
                    String(localized: "settings.volumes.updates.check",
                           defaultValue: "Check for Updates"),
                    systemImage: "arrow.triangle.2.circlepath"
                )
            }
        }
        .disabled(isCheckingForUpdates || downloadedVolumes.isEmpty || appState.manifestStore.diffResult == nil)
        .accessibilityLabel(
            String(localized: "settings.volumes.updates.check.a11y",
                   defaultValue: "Check downloaded volumes for upstream updates")
        )
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
                            let url = entry.downloadUrl
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
        guard appState.downloadManager != nil else { return }
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
            await performEnqueueiOS(toEnqueue)
        }
    }

    private func performEnqueueiOS(_ volumes: [VolumeManifestEntry]) async {
        guard let dm = appState.downloadManager else { return }
        for entry in volumes {
            let url = entry.downloadUrl
            await dm.enqueueDownload(volumeId: entry.volumeId, downloadUrl: url)
        }
        await MainActor.run {
            let count = volumes.count
            enqueuedMessage = String(
                localized: "settings.downloadManager.enqueued",
                defaultValue: "\(count) volume\(count == 1 ? "" : "s") queued for download.")
        }
        #if DEBUG
        print("[Settings] Downloads enqueued \(volumes.count) volumes.")
        #endif
    }

    /// Diffs every downloaded volume's git blob SHA against the live manifest and
    /// populates `updatableVolumes` with any that have changed upstream.
    ///
    /// Runs only on explicit user request (the "Check for Updates" button) — never
    /// automatically at launch, since hashing every downloaded volume is too costly
    /// to run silently.
    private func checkForUpdates() async {
        guard let dm = appState.downloadManager,
              let liveInfo = appState.manifestStore.diffResult?.liveInfoByVolumeId else {
            return
        }
        await MainActor.run { isCheckingForUpdates = true }
        let known = appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
        let result = await VolumeUpdateChecker.updatableVolumes(
            known: known,
            liveInfoByVolumeId: liveInfo,
            downloadManager: dm
        )
        await MainActor.run {
            updatableVolumes = result
            hasCheckedForUpdates = true
            isCheckingForUpdates = false
        }
    }

    /// Re-downloads `updatable` (overwriting the stale local copy) and removes it
    /// from `updatableVolumes`. `onVolumeDownloaded` re-indexes the volume
    /// automatically once the transfer completes; the UPSERT path preserves the
    /// user's notes, highlights, tags, and summaries.
    private func updateVolume(_ updatable: UpdatableVolume) async {
        guard let dm = appState.downloadManager else { return }
        await dm.enqueueDownload(volumeId: updatable.id, downloadUrl: updatable.entry.downloadUrl, force: true)
        await MainActor.run {
            updatableVolumes.removeAll { $0.id == updatable.id }
        }
    }

    /// Re-downloads every volume currently listed in `updatableVolumes`.
    private func updateAllVolumes() async {
        for updatable in updatableVolumes {
            await updateVolume(updatable)
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

/// Shows aggregate and per-volume storage usage, per-volume indexing status,
/// and indexing controls matching the macOS Storage pane.
///
/// ## Indexing Status (Session 67)
/// Each per-volume row indicates whether the volume has been indexed for full-text
/// search (using `IndexingPipeline.isVolumeIndexed`). Unindexed volumes display a
/// "Reindex" button that calls `IndexingPipeline.indexVolume` inline.
///
/// ## Reindex All (Session 118)
/// Absorbed from the former standalone `ReindexView`. The "Reindex" section at the
/// bottom of the form contains the explanatory text, optional "Needs Attention" list
/// for interrupted volumes, and the Reindex All Volumes button with live progress.
///
/// ## Indexing Parity (Session 2026-06-08)
/// Adds "Index Remaining" (index only unindexed volumes) and "Delete Index & Rebuild"
/// (wipe FTS5 index + reindex from scratch) to match the macOS `SettingsStoragePane`.
/// A `BatchKind`-driven queue progress card shows live progress during any batch.
///
/// ## Scroll Affordance (Session 67)
/// The Form omits `maxHeight: .infinity` so the `NavigationSplitView` detail column
/// bounds it correctly and it scrolls when the per-volume list is long.
///
/// ## Diagnostics (Session 154)
/// A "Diagnostics" section after Reindex adds "Check Index Integrity" (runs
/// `IndexingPipeline.checkIndexIntegrity()` and shows a green "No problems found"
/// or a list of problem descriptions with a suggestion to rebuild) and "Rebuild
/// Spotlight Index" (clears and re-submits the system Spotlight index from
/// `document_cache` without re-parsing XML).
private struct StorageManagementView: View {

    // MARK: - Batch tracking

    /// Tracks the kind and progress of a Settings-triggered bulk indexing run.
    /// Set at the start of `indexRemaining()` / `startReindexAll()` / `rebuildIndex()`;
    /// cleared on completion. Drives `indexingQueueCard` visibility and header label.
    private enum BatchKind {
        /// Iterating through unindexed volumes one by one; `current` is 1-based.
        case indexRemaining(current: Int, total: Int)
        /// Running `indexAllVolumes()` as a single call.
        case reindexAll(total: Int)
        /// Running `removeAllVolumesFromIndex()` followed by `indexAllVolumes()`.
        case rebuildAll(total: Int)
    }

    @Environment(AppState.self) private var appState

    @State private var report: StorageReport? = nil
    @State private var loadError: String? = nil

    /// Indexed status per volumeId. `nil` means not yet checked or pipeline unavailable.
    @State private var indexedStatus: [String: Bool] = [:]
    /// VolumeId currently being reindexed via per-volume button; drives inline ProgressView.
    @State private var reindexingVolumeId: String? = nil
    /// Per-volume reindex errors (rare, but surfaced inline).
    @State private var reindexErrors: [String: String] = [:]

    // MARK: Batch state (unified across all three operations)

    /// Non-nil while any Settings-triggered bulk indexing batch is active.
    /// Drives `indexingQueueCard` visibility and header label.
    @State private var settingsBatch: BatchKind? = nil
    /// Controls the "Delete Index & Rebuild" confirmation alert.
    @State private var showRebuildConfirmation = false

    // MARK: Reindex All legacy state (kept for the existing "Reindex All" UI path)

    /// `true` while `indexAllVolumes()` is running via the "Reindex All" button.
    @State private var isReindexAll = false
    /// Stream state from `pipeline.progress` during a Reindex All operation.
    @State private var reindexAllProgressState: IndexingProgress.State = .idle
    /// Error message from a failed Reindex All operation.
    @State private var reindexAllError: String? = nil
    /// Tracks an individual interrupted-volume re-index; `"all"` when doing the bulk sweep.
    @State private var reindexingInterruptedId: String? = nil

    // MARK: Diagnostics state (Session 154; integrity check moved into
    // IndexHealthView in Session 162)

    /// `true` while `rebuildSpotlightIndex()` is running.
    @State private var spotlightRebuildRunning = false
    /// `true` once a Spotlight rebuild has completed successfully.
    @State private var spotlightRebuildSucceeded = false
    /// Error message from a failed Spotlight rebuild.
    @State private var spotlightRebuildError: String? = nil

    #if os(iOS)
    /// Whether indexing progress shows a Live Activity / Dynamic Island widget (Session 154).
    @AppStorage(SettingsKeys.liveActivityEnabled) private var liveActivityEnabled = true
    #endif

    /// User preference: precompute heavy word clouds (corpus/subseries) in the
    /// background after indexing so they open instantly. Mirrors the key read by
    /// `WordCloudPrecomputeQueue`.
    @AppStorage("frus.wordcloud.backgroundPrecompute") private var precomputeWordClouds = true

    var body: some View {
        Form {
            #if os(iOS)
            Section(footer: Text(String(
                localized: "settings.storage.wordcloud.footer",
                defaultValue: "When enabled, the most demanding word clouds are computed in the background after indexing, so they open instantly. Runs only while the device is idle."
            ))) {
                Toggle(String(localized: "settings.storage.wordcloud.toggle",
                              defaultValue: "Precompute word clouds in background"),
                       isOn: $precomputeWordClouds)
            }
            #endif
            Section(header: Text(String(localized: "settings.storage.aggregate.header",
                                        defaultValue: "Total Storage Used")),
                    footer: Text(String(localized: "settings.storage.aggregate.footer",
                                        defaultValue: "For reference: the full FRUS corpus uses ~3.4 GB of XML and ~9 GB of search index — approximately 12–13 GB total on device."))) {
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

            // Needs Attention: interrupted volumes (previously in standalone ReindexView).
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
                                Text(title).font(.callout).lineLimit(1)
                                Text(volumeId).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(String(localized: "settings.reindex.interrupted.reindex",
                                          defaultValue: "Re-index")) {
                                reindexInterrupted(volumeId: volumeId)
                            }
                            .buttonStyle(.bordered)
                            .disabled(isReindexAll || reindexingInterruptedId != nil
                                      || appState.indexingPipeline == nil)
                        }
                    }

                    Button {
                        startReindexAllInterrupted(interrupted)
                    } label: {
                        if reindexingInterruptedId == "all" {
                            HStack {
                                ProgressView().padding(.trailing, 4)
                                Text(reindexAllProgressLabel).font(.callout)
                            }
                        } else {
                            Label(
                                String(localized: "settings.reindex.interrupted.all",
                                       defaultValue: "Re-index All Interrupted"),
                                systemImage: "exclamationmark.triangle"
                            )
                        }
                    }
                    .disabled(isReindexAll || reindexingInterruptedId != nil
                              || appState.indexingPipeline == nil)
                }
            }

            // Reindex All section: absorbed from former standalone ReindexView.
            #if os(iOS)
            Section {
                Toggle(
                    String(localized: "settings.storage.liveActivity.label",
                           defaultValue: "Show Indexing Live Activity"),
                    isOn: $liveActivityEnabled
                )
                .accessibilityHint(
                    String(localized: "settings.storage.liveActivity.a11y",
                           defaultValue: "When off, indexing progress will not appear in the Dynamic Island or on the Lock Screen")
                )
            } footer: {
                Text(String(localized: "settings.storage.liveActivity.footer",
                            defaultValue: "Shows indexing progress in the Dynamic Island and on the Lock Screen while volumes are being indexed."))
            }
            #endif

            Section(String(localized: "settings.storage.reindex.header",
                           defaultValue: "Reindex")) {
                Text(String(localized: "settings.reindex.about.body",
                            defaultValue: "Rebuilds the full-text search index from all downloaded volumes. Use this if search results are missing or incorrect."))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                // Queue progress card — shown while any batch is running.
                if settingsBatch != nil || appState.currentIndexingProgress != nil {
                    indexingQueueCard
                }

                Button {
                    Task { await indexRemaining() }
                } label: {
                    Label(
                        String(localized: "settings.reindex.remaining.button",
                               defaultValue: "Index Remaining"),
                        systemImage: "plus.circle"
                    )
                }
                .disabled(isAnythingIndexing || appState.indexingPipeline == nil)
                .accessibilityLabel(
                    String(localized: "settings.reindex.remaining.a11y",
                           defaultValue: "Index only volumes that have not been indexed yet")
                )

                Button {
                    startReindexAll()
                } label: {
                    if isReindexAll {
                        HStack {
                            ProgressView().padding(.trailing, 4)
                            Text(reindexAllProgressLabel).font(.callout)
                        }
                    } else {
                        Label(
                            String(localized: "settings.reindex.start.button",
                                   defaultValue: "Reindex All Volumes"),
                            systemImage: "magnifyingglass.circle"
                        )
                    }
                }
                .disabled(isAnythingIndexing || appState.indexingPipeline == nil)
                .accessibilityLabel(
                    String(localized: "settings.reindex.start.a11y",
                           defaultValue: "Reindex all downloaded FRUS volumes")
                )

                Button(role: .destructive) {
                    showRebuildConfirmation = true
                } label: {
                    Label(
                        String(localized: "settings.reindex.rebuild.button",
                               defaultValue: "Delete Index & Rebuild"),
                        systemImage: "trash.circle"
                    )
                }
                .disabled(isAnythingIndexing || appState.indexingPipeline == nil)
                .accessibilityLabel(
                    String(localized: "settings.reindex.rebuild.a11y",
                           defaultValue: "Delete the entire search index and rebuild from scratch")
                )

                if case .completed(let volumes, let docs) = reindexAllProgressState {
                    Label(
                        String(localized: "settings.reindex.done",
                               defaultValue: "Completed: \(volumes) volume\(volumes == 1 ? "" : "s"), \(docs) documents"),
                        systemImage: "checkmark.circle"
                    )
                    .foregroundStyle(.green)
                    .font(.callout)
                }

                if let error = reindexAllError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }

            Section {
                IndexHealthView(actionsDisabled: isAnythingIndexing)
            } header: {
                Text(String(localized: "settings.storage.indexHealth.header",
                            defaultValue: "Index Health"))
            } footer: {
                Text(String(localized: "settings.storage.indexHealth.footer",
                            defaultValue: "The index updates itself automatically when a new version of the app improves indexing. Check Integrity runs the full corruption diagnostic on demand."))
            }

            Section {
                Button {
                    Task { await runRebuildSpotlightIndex() }
                } label: {
                    if spotlightRebuildRunning {
                        HStack {
                            ProgressView().padding(.trailing, 4)
                            Text(String(localized: "settings.storage.spotlight.running",
                                        defaultValue: "Rebuilding…")).font(.callout)
                        }
                    } else {
                        Label(
                            String(localized: "settings.storage.spotlight.button",
                                   defaultValue: "Rebuild Spotlight Index"),
                            systemImage: "magnifyingglass"
                        )
                    }
                }
                .disabled(isAnythingIndexing || spotlightRebuildRunning || appState.indexingPipeline == nil)
                .accessibilityLabel(
                    String(localized: "settings.storage.spotlight.a11y",
                           defaultValue: "Clear and re-submit the system Spotlight search index")
                )

                if spotlightRebuildSucceeded {
                    Label(
                        String(localized: "settings.storage.spotlight.ok",
                               defaultValue: "Spotlight index rebuilt"),
                        systemImage: "checkmark.circle"
                    )
                    .foregroundStyle(.green)
                    .font(.callout)
                }

                if let error = spotlightRebuildError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            } header: {
                Text(String(localized: "settings.storage.diagnostics.header",
                            defaultValue: "Diagnostics"))
            } footer: {
                Text(String(localized: "settings.storage.diagnostics.footer",
                            defaultValue: "Run these checks if search results look incomplete, or if FRUS documents are missing from the system Spotlight search."))
            }
        }
        .navigationTitle(String(localized: "storage.navigationTitle",
                                defaultValue: "Storage & Index"))
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
        .alert(
            String(localized: "settings.reindex.rebuild.confirm.title",
                   defaultValue: "Delete Index and Rebuild?"),
            isPresented: $showRebuildConfirmation
        ) {
            Button(String(localized: "settings.reindex.rebuild.confirm.action",
                          defaultValue: "Delete & Rebuild"),
                   role: .destructive) {
                Task { await rebuildIndex() }
            }
            Button(String(localized: "settings.reindex.rebuild.confirm.cancel",
                          defaultValue: "Cancel"),
                   role: .cancel) {}
        } message: {
            let count = report?.perVolume.count ?? 0
            Text(String(localized: "settings.reindex.rebuild.confirm.message",
                        defaultValue: "This will permanently delete the entire search index, then rebuild it by re-parsing all \(count) downloaded volume\(count == 1 ? "" : "s"). Your research notes, highlights, summaries, collections, and tags will not be affected."))
        }
    }

    // MARK: - Indexing Queue Card

    /// Inline progress card shown inside the Reindex section while a Settings-triggered
    /// batch is running. Mirrors the macOS `SettingsStoragePane.indexingQueueCard`.
    @ViewBuilder
    private var indexingQueueCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                switch settingsBatch {
                case .indexRemaining(let current, let total):
                    Text(String(localized: "settings.storage.indexing.remaining",
                                defaultValue: "Volume \(current) of \(total)"))
                        .font(.callout.weight(.medium))
                case .reindexAll(let total):
                    Text(String(localized: "settings.storage.reindexing.all",
                                defaultValue: "Reindexing all \(total) volumes"))
                        .font(.callout.weight(.medium))
                case .rebuildAll(let total):
                    Text(String(localized: "settings.storage.rebuilding.all",
                                defaultValue: "Rebuilding index for all \(total) volumes"))
                        .font(.callout.weight(.medium))
                case nil:
                    Text(String(localized: "settings.storage.indexing.generic",
                                defaultValue: "Indexing…"))
                        .font(.callout.weight(.medium))
                }
                Spacer()
            }

            if let update = appState.currentIndexingProgress {
                let resolvedTitle = appState.manifestStore
                    .entry(forVolumeId: update.volumeId)?.title
                Text(resolvedTitle ?? update.volumeId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if update.totalDocuments > 0 {
                    ProgressView(
                        value: Double(update.completedDocuments),
                        total: Double(update.totalDocuments)
                    )
                    .progressViewStyle(.linear)
                    HStack {
                        Text(String(localized: "settings.storage.indexing.docCount",
                                    defaultValue: "\(update.completedDocuments) / \(update.totalDocuments) documents"))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer()
                        if update.docsPerSecond > 0 {
                            Text(String(format: String(localized: "settings.storage.indexing.throughput",
                                                       defaultValue: "%.0f docs/s"),
                                        update.docsPerSecond))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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

    // MARK: - Computed

    /// `true` when any batch-indexing operation is in progress, used to disable
    /// all action buttons to prevent concurrent batch conflicts.
    private var isAnythingIndexing: Bool {
        settingsBatch != nil || isReindexAll || reindexingInterruptedId != nil
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
        // The single-volume reindex mutated the aux tables — reopen the read-only stores (#275).
        appState.refreshReadOnlyStores()
        if reindexingVolumeId == volumeId { reindexingVolumeId = nil }
    }

    // MARK: - Reindex All helpers

    private var reindexAllProgressLabel: String {
        switch reindexAllProgressState {
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

    private func startReindexAll() {
        guard let pipeline = appState.indexingPipeline else { return }
        isReindexAll = true
        reindexAllProgressState = .idle
        reindexAllError = nil

        Task {
            async let progressTask: Void = {
                for await event in pipeline.progress {
                    await MainActor.run { reindexAllProgressState = event.state }
                }
            }()
            do {
                try await pipeline.indexAllVolumes()
            } catch {
                await MainActor.run {
                    reindexAllError = error.localizedDescription
                    #if DEBUG
                    print("[Settings] Reindex All failed: \(error)")
                    #endif
                }
            }
            _ = await progressTask
            // Reopen the read-only stores so analytics / citation lookup don't read through the
            // now-stale boot connections after this in-session rebuild (#275).
            await MainActor.run {
                appState.refreshReadOnlyStores()
                isReindexAll = false
            }
        }
    }

    private func reindexInterrupted(volumeId: String) {
        guard let pipeline = appState.indexingPipeline else { return }
        reindexingInterruptedId = volumeId
        Task {
            do {
                try await pipeline.indexVolume(volumeId)
            } catch {
                await MainActor.run {
                    reindexAllError = error.localizedDescription
                }
            }
            // The single-volume reindex mutated the aux tables too — reopen the read-only
            // stores so they don't strand a stale connection (#275).
            await MainActor.run {
                appState.refreshReadOnlyStores()
                reindexingInterruptedId = nil
            }
        }
    }

    private func startReindexAllInterrupted(_ volumeIds: [String]) {
        guard let pipeline = appState.indexingPipeline else { return }
        reindexingInterruptedId = "all"
        Task {
            for volumeId in volumeIds {
                do {
                    try await pipeline.indexVolume(volumeId)
                } catch {
                    await MainActor.run {
                        reindexAllError = error.localizedDescription
                        #if DEBUG
                        print("[Settings] Re-index interrupted volume \(volumeId) failed: \(error)")
                        #endif
                    }
                }
            }
            await MainActor.run {
                appState.refreshReadOnlyStores()
                reindexingInterruptedId = nil
            }
        }
    }

    // MARK: - Index Remaining

    /// Indexes only the downloaded volumes that have not been indexed yet,
    /// iterating one by one with `BatchKind.indexRemaining` progress tracking.
    ///
    /// Mirrors `SettingsStoragePane.indexRemaining()` on macOS.
    private func indexRemaining() async {
        guard let pipeline = appState.indexingPipeline,
              let rep = report else { return }
        let unindexed = rep.perVolume.filter {
            (try? pipeline.isVolumeIndexed($0.volumeId)) != true
        }
        guard !unindexed.isEmpty else { return }
        for (idx, entry) in unindexed.enumerated() {
            settingsBatch = .indexRemaining(current: idx + 1, total: unindexed.count)
            do {
                try await pipeline.indexVolume(entry.volumeId)
                indexedStatus[entry.volumeId] = true
            } catch {
                #if DEBUG
                print("[Settings] indexRemaining: \(entry.volumeId) failed — \(error)")
                #endif
            }
        }
        // Newly indexed volumes added rows the boot read-only connections can't see — reopen them
        // so analytics / citation lookup include the just-indexed volumes (#275).
        appState.refreshReadOnlyStores()
        settingsBatch = nil
        // Reload report to refresh per-volume indexed status.
        if let dm = appState.downloadManager {
            report = try? await dm.storageReport(indexDirectory: appState.indexDirectory)
        }
    }

    // MARK: - Rebuild Index

    /// Wipes the entire search index then rebuilds it from all downloaded volumes.
    ///
    /// Unlike `startReindexAll()` (which relies on per-volume pre-deletes inside
    /// `storeIndexData`), this issues a single `removeAllVolumesFromIndex()` first,
    /// guaranteeing a fully clean state before the rebuild begins.
    ///
    /// Mirrors `SettingsStoragePane.rebuildIndex()` on macOS.
    private func rebuildIndex() async {
        guard let pipeline = appState.indexingPipeline else { return }
        let total = report?.perVolume.count ?? 0
        settingsBatch = .rebuildAll(total: total)
        do {
            try await pipeline.removeAllVolumesFromIndex()
            appState.indexedVolumeIds = []
        } catch {
            settingsBatch = nil
            reindexAllError = error.localizedDescription
            #if DEBUG
            print("[Settings] rebuildIndex: removeAllVolumesFromIndex failed — \(error)")
            #endif
            return
        }
        do {
            try await pipeline.indexAllVolumes()
        } catch {
            reindexAllError = error.localizedDescription
            #if DEBUG
            print("[Settings] rebuildIndex: indexAllVolumes failed — \(error)")
            #endif
        }
        // Reopen the read-only stores post-rebuild so analytics / citation lookup don't read the
        // stale boot connections (#275).
        appState.refreshReadOnlyStores()
        settingsBatch = nil
        // Refresh indexed status.
        if let dm = appState.downloadManager {
            report = try? await dm.storageReport(indexDirectory: appState.indexDirectory)
        }
        if let rep = report {
            for perVol in rep.perVolume {
                indexedStatus[perVol.volumeId] =
                    (try? pipeline.isVolumeIndexed(perVol.volumeId)) ?? false
            }
        }
    }

    // MARK: - Diagnostics (Session 154; integrity check moved into IndexHealthView)

    /// Runs `IndexingPipeline.rebuildSpotlightIndex()`, clearing and re-submitting
    /// the system Spotlight index from `document_cache` without re-parsing XML.
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
            #if DEBUG
            print("[Settings] rebuildSpotlightIndex failed: \(error)")
            #endif
        }
        spotlightRebuildRunning = false
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
                        // Reopen the read-only stores so the sideloaded volume's cross-references /
                        // mentions appear in analytics without a relaunch (#275).
                        await MainActor.run { appState.refreshReadOnlyStores() }
                    }
                }
            } catch {
                importResult = .failure(error.localizedDescription)
            }
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

    func mergeTag(source: UserTag, into target: UserTag) {
        // Capture IDs before any modification.
        let sourceId = source.id
        let targetId = target.id

        // 1. Re-tag ResearchNotes.
        // Using a #Predicate with array.contains on a transformable [UUID] column
        // crashes on SwiftData — fetch all notes and filter in memory instead.
        let allNotes = (try? modelContext.fetch(FetchDescriptor<ResearchNote>())) ?? []
        var noteCount = 0
        for note in allNotes where note.userTagIds.contains(sourceId) {
            var ids = note.userTagIds.filter { $0 != sourceId }
            if !ids.contains(targetId) { ids.append(targetId) }
            note.userTagIds = ids
            noteCount += 1
        }

        // 2. Re-tag DocumentTagAssignments (previously omitted — caused orphaned assignments).
        let allAssignments = (try? modelContext.fetch(FetchDescriptor<DocumentTagAssignment>())) ?? []
        var assignmentCount = 0
        for assignment in allAssignments where assignment.tagId == sourceId {
            assignment.tagId = targetId
            assignmentCount += 1
        }

        // 3. Delete the source tag last, after all references have been updated.
        modelContext.delete(source)

        #if DEBUG
        print("[Settings] Merged '\(source.name)' → '\(target.name)': "
              + "\(noteCount) notes, \(assignmentCount) assignments updated")
        #endif
    }
}

// MARK: - ProjectsSettingsView

/// iOS Settings → Research → Projects: rename, merge, and delete `Project`
/// records.
///
/// Mirrors the `UserTagsView` interaction pattern (tap or leading swipe to
/// rename, trailing swipe to delete) with a context menu "Merge into…" action
/// in place of the always-visible merge button used by the macOS
/// `SettingsProjectsPane`. Delete and merge mutations are shared with macOS
/// via `ProjectAdminService`.
///
/// Project creation and active-project switching are handled elsewhere
/// (`ProjectPickerMenu`, `ProjectEditorView`); this view is solely for
/// administering existing projects.
///
/// Version history:
///   1.0 — Session 153: initial implementation (closes the iOS delete/merge gap)
private struct ProjectsSettingsView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.name) private var projects: [Project]

    @State private var renamingProject: Project? = nil
    @State private var renameText = ""
    @State private var mergingProject: Project? = nil
    @State private var projectToDelete: Project? = nil
    @State private var showDeleteConfirmation = false

    var body: some View {
        Form {
            Section {
                if projects.isEmpty {
                    Text(String(localized: "settings.projects.empty",
                                defaultValue: "No projects created yet."))
                        .foregroundStyle(.secondary)
                        .font(.callout)
                } else {
                    ForEach(projects) { project in
                        let isRenaming = renamingProject?.id == project.id
                        Group {
                            if isRenaming {
                                TextField(
                                    String(localized: "settings.projects.rename.placeholder",
                                           defaultValue: "Project name"),
                                    text: $renameText
                                )
                                .onSubmit { commitRename() }
                                .accessibilityLabel(
                                    String(localized: "settings.projects.rename.a11y",
                                           defaultValue: "Rename project \(project.name)")
                                )
                            } else {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(project.name)
                                    if let question = project.researchQuestion, !question.isEmpty {
                                        Text(question)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard renamingProject == nil else { return }
                            renamingProject = project
                            renameText = project.name
                        }
                        // Leading swipe: Rename. Mirrors UserTagsView so the action is
                        // discoverable for users unfamiliar with tap-to-rename.
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if !isRenaming {
                                Button {
                                    renamingProject = project
                                    renameText = project.name
                                } label: {
                                    Label(
                                        String(localized: "settings.projects.rename.swipe",
                                               defaultValue: "Rename"),
                                        systemImage: "pencil"
                                    )
                                }
                                .tint(.accentColor)
                                .accessibilityLabel(
                                    String(localized: "settings.projects.rename.swipe.a11y",
                                           defaultValue: "Rename project \(project.name)")
                                )
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                projectToDelete = project
                                showDeleteConfirmation = true
                            } label: {
                                Label(
                                    String(localized: "settings.projects.delete.swipe",
                                           defaultValue: "Delete"),
                                    systemImage: "trash"
                                )
                            }
                            .accessibilityLabel(
                                String(localized: "settings.projects.delete.swipe.a11y",
                                       defaultValue: "Delete project \(project.name)")
                            )
                        }
                        .contextMenu {
                            Button {
                                mergingProject = project
                            } label: {
                                Label(
                                    String(localized: "settings.projects.merge.button",
                                           defaultValue: "Merge into…"),
                                    systemImage: "arrow.triangle.merge"
                                )
                            }
                            .disabled(projects.count < 2)
                        }
                    }
                }
            } header: {
                Text(String(localized: "settings.projects.list.header", defaultValue: "Projects"))
            } footer: {
                Text(String(localized: "settings.projects.list.footer",
                            defaultValue: "Tap or swipe right to rename. Touch and hold for merge options. Swipe left to delete."))
                    .font(.caption)
            }
        }
        .navigationTitle(String(localized: "settings.projects.title", defaultValue: "Projects"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .frame(maxWidth: .infinity)
        .scrollIndicators(.visible)
        #endif
        .toolbar {
            if renamingProject != nil {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "settings.projects.rename.done", defaultValue: "Done")) {
                        commitRename()
                    }
                }
            }
        }
        .sheet(item: $mergingProject) { sourceProject in
            MergeProjectSheet(
                sourceProject: sourceProject,
                allProjects: projects.filter { $0.id != sourceProject.id },
                onMerge: { targetProject in
                    ProjectAdminService.merge(sourceProject, into: targetProject, context: modelContext, appState: appState)
                    mergingProject = nil
                }
            )
        }
        .confirmationDialog(
            String(localized: "settings.projects.delete.title", defaultValue: "Delete Project?"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.projects.delete.confirm", defaultValue: "Delete"), role: .destructive) {
                if let project = projectToDelete {
                    ProjectAdminService.delete(project, context: modelContext, appState: appState)
                }
                projectToDelete = nil
            }
            Button(String(localized: "settings.projects.delete.cancel", defaultValue: "Cancel"), role: .cancel) {
                projectToDelete = nil
            }
        } message: {
            Text(String(localized: "settings.projects.delete.message",
                        defaultValue: "Activity records are kept but unlinked from this project."))
        }
    }

    private func commitRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let project = renamingProject {
            project.name = trimmed
        }
        renamingProject = nil
        renameText = ""
    }
}

// MARK: - MergeTagSheet

struct MergeTagSheet: View {
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
        #if os(macOS)
        macBody
        #else
        iOSBody
        #endif
    }

    // MARK: - macOS body

    #if os(macOS)
    /// macOS-native layout: title row + tag list + explanation + Cancel/Merge button bar.
    /// `SettingsView` can be presented on macOS (it has a `#if !os(iOS)` dismiss environment),
    /// so this sheet must render correctly on both platforms.
    private var macBody: some View {
        VStack(spacing: 0) {
            Text(String(localized: "settings.tags.merge.title", defaultValue: "Merge Tag"))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "settings.tags.merge.source.header",
                                defaultValue: "Merge '\(sourceTag.name)' into:"))
                        .font(.callout.weight(.medium))

                    ForEach(allTags) { tag in
                        mergeTagRow(tag: tag)
                    }

                    Divider()

                    Text(String(localized: "settings.tags.merge.explanation",
                                defaultValue: "All notes tagged '\(sourceTag.name)' will be re-tagged with the selected tag. '\(sourceTag.name)' will be deleted."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            }

            Divider()

            HStack {
                Button(String(localized: "settings.tags.merge.cancel",
                              defaultValue: "Cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(String(localized: "settings.tags.merge.confirm",
                              defaultValue: "Merge")) {
                    if let id = selectedTagId,
                       let target = allTags.first(where: { $0.id == id }) {
                        onMerge(target)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(selectedTagId == nil)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 380, minHeight: 260)
    }
    #endif

    // MARK: - iOS body

    #if os(iOS)
    private var iOSBody: some View {
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
            .navigationBarTitleDisplayMode(.inline)
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
        .presentationDetents([.medium, .large])
    }
    #endif
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
                      defaultValue: "\(count) \(count == 1 ? "summary" : "summaries") generated")
    }
}

// MARK: - ZoteroIntegrationView

/// Settings → Integrations → Zotero: connect a Zotero account by pasting a Web API
/// key, which is verified (resolving the user ID) and stored in the Keychain. Once
/// connected, "Send to Zotero Library…" appears on collections and documents.
///
/// Version history:
///   1.0 — Zotero Web API integration (Phase 2)
struct ZoteroIntegrationView: View {

    @State private var keyText: String = ""
    @State private var isConnecting = false
    @State private var connectedUsername: String?
    @State private var isConnected = false
    @State private var errorMessage: String?

    private let store = ZoteroAccountStore.shared
    private let client = ZoteroAPIClient()

    /// Deep link that pre-fills a new key with library + notes + write access.
    private let getKeyURL = URL(string:
        "https://www.zotero.org/settings/keys/new?name=FRUS%20Explorer&library_access=1&notes_access=1&write_access=1")

    var body: some View {
        Form {
            Section {
                Text(String(localized: "settings.zotero.about.body",
                            defaultValue: "Send FRUS documents — with your tags and research notes — straight into your Zotero library, where they sync to all your devices including the Zotero iOS app. This is the only way to get FRUS annotations into Zotero on iPhone and iPad."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Text(String(localized: "settings.zotero.about.header", defaultValue: "About"))
            }

            if isConnected {
                Section {
                    LabeledContent(
                        String(localized: "settings.zotero.connectedAs", defaultValue: "Connected as"),
                        value: connectedUsername ?? String(localized: "settings.zotero.unknownUser",
                                                           defaultValue: "your library")
                    )
                    Button(String(localized: "settings.zotero.disconnect", defaultValue: "Disconnect"),
                           role: .destructive) {
                        store.disconnect()
                        refresh()
                    }
                } header: {
                    Text(String(localized: "settings.zotero.account.header", defaultValue: "Account"))
                }
            } else {
                Section {
                    if let getKeyURL {
                        Link(destination: getKeyURL) {
                            HStack {
                                Label(String(localized: "settings.zotero.getKey",
                                             defaultValue: "Create a Zotero API key"), systemImage: "key")
                                Spacer()
                                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityAddTraits(.isLink)
                    }
                    SecureField(
                        String(localized: "settings.zotero.field.placeholder",
                               defaultValue: "Paste your Zotero API key…"),
                        text: $keyText
                    )
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.asciiCapable)
                    #endif
                    Button {
                        connect()
                    } label: {
                        if isConnecting { ProgressView() }
                        else { Text(String(localized: "settings.zotero.connect", defaultValue: "Connect")) }
                    }
                    .disabled(keyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isConnecting)
                } header: {
                    Text(String(localized: "settings.zotero.connect.header", defaultValue: "Connect"))
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
        .navigationTitle(String(localized: "settings.zotero.title", defaultValue: "Zotero"))
        .onAppear { refresh() }
    }

    private func refresh() {
        isConnected = store.isConnected
        connectedUsername = store.username
    }

    private func connect() {
        let key = keyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        isConnecting = true
        errorMessage = nil
        Task {
            do {
                let info = try await client.resolveAccount(key: key)
                store.storeKey(key)
                store.setAccount(userID: info.userID, username: info.username)
                keyText = ""
                refresh()
            } catch {
                errorMessage = (error as? ZoteroAPIError)?.errorDescription ?? error.localizedDescription
            }
            isConnecting = false
        }
    }
}

// MARK: - NARAKeyView

private struct NARAKeyView: View {

    @State private var keyText: String = ""
    @State private var hasExistingKey: Bool = false
    @State private var isSaving: Bool = false
    @State private var saveResult: SaveResult? = nil
    @State private var callCount: Int = 0

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

                if let url = URL(string: "https://www.archives.gov/research/catalog/help/api") {
                    Link(destination: url) {
                        HStack {
                            Label(
                                String(localized: "settings.naraKey.apiLink",
                                       defaultValue: "NARA Catalog API — get a free key"),
                                systemImage: "key"
                            )
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel(
                        String(localized: "settings.naraKey.apiLink.a11y",
                               defaultValue: "NARA Catalog API help page — request a free API key")
                    )
                    .accessibilityAddTraits(.isLink)
                }
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

            Section(String(localized: "settings.naraKey.usage.header",
                           defaultValue: "Usage (Last 30 Days)")) {
                HStack {
                    Text(String(localized: "settings.naraKey.usage.count",
                                defaultValue: "\(callCount) API call\(callCount == 1 ? "" : "s")"))
                        .font(.callout)
                    Spacer()
                    Text(String(localized: "settings.naraKey.usage.limitNote",
                                defaultValue: "Limit not enforced by FRUS Explorer"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
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
            callCount = NARAAPIKeyStore.shared.callCountLast30Days
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

/// Three-tier reset UI, ordered least → most destructive: iCloud Sync, Local
/// Data, and the two-step "Reset App to Initial State" action.
///
/// ## What is deleted
/// - **Reset iCloud Sync**: the local SwiftData SQLite store, forcing a fresh
///   download from CloudKit on next launch. iCloud data is untouched.
/// - **Reset Local Data**: downloaded volume XML files and the search index
///   (`frus.db`), via the shared `ResetService.resetLocalData(appState:)`. The
///   local SwiftData store and iCloud-synced data are untouched.
/// - **Reset App to Initial State**: everything `ResetService.resetLocalData`
///   clears, plus all SwiftData user-generated records: `ResearchNote`,
///   `UserTag`, `GeneratedSummary`, `ReadingHistoryEntry`, `Collection`,
///   `CollectionEntry`, `SummarizationPrompt`, `Project`, and the active
///   project selection (`AppState.activeProjectId`).
///
/// ## Post-reset navigation
/// Both platforms now set `hasCompletedOnboarding = false` directly after clearing data.
/// - **iOS**: Settings is a persistent tab — no sheet is on screen.
/// - **macOS**: Settings is now a `Settings` scene (independent window, not a modal sheet).
///   There is no animation race with `ContentView`, so direct assignment is safe.
///
/// ## Confirmation gates
/// The user must confirm twice (two `confirmationDialog` calls) before `performReset()`
/// is invoked, guarding against accidental taps. Sync and Local resets each require
/// a single confirmation.
///
/// Version history:
///   1.0 — Session 24: initial implementation
///   1.1 — Session 32: added `Project` deletion; switched to two-phase sheet-dismissal
///          for safe post-reset onboarding navigation (macOS)
///   1.2 — Session 44: iOS path simplified to direct assignment
///   1.3 — Session 46: macOS path also simplified; pendingOnboardingAfterReset removed
///   1.4 — Session 153: added the "Reset Local Data" tier (between Sync and Full),
///          backed by the shared `ResetService`, closing the iOS gap with
///          macOS `SettingsResetPane`
private struct ResetView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var showFirstConfirmation  = false
    @State private var showSecondConfirmation = false
    @State private var showSyncReset          = false
    @State private var showLocalReset         = false
    @State private var isResetting = false
    @State private var resetError: String? = nil

    var body: some View {
        Form {
            // iCloud sync reset — least destructive, recommended when sync is broken
            Section(header: Text(String(localized: "settings.reset.sync.header",
                                        defaultValue: "iCloud Sync"))) {
                Text(String(localized: "settings.reset.sync.warning",
                            defaultValue: "If iCloud sync is consistently reporting errors, clearing the local sync state forces a fresh download from iCloud. Your data in iCloud is not deleted."))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Button(String(localized: "settings.reset.sync.button",
                              defaultValue: "Reset iCloud Sync"), role: .destructive) {
                    showSyncReset = true
                }
                .disabled(isResetting)
            }

            // Local-only reset — deletes downloaded volumes and the search index from
            // this device. iCloud-synced data (notes, collections, tags, projects) is
            // untouched and will re-sync on next launch.
            Section(header: Text(String(localized: "settings.reset.local.header",
                                        defaultValue: "This Device"))) {
                Text(String(localized: "settings.reset.local.warning",
                            defaultValue: "Deletes all downloaded volume files and the search index from this device. Your notes, collections, tags, and projects remain in iCloud and will be restored the next time the app launches."))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Button(String(localized: "settings.reset.local.button",
                              defaultValue: "Reset Local Data"), role: .destructive) {
                    showLocalReset = true
                }
                .disabled(isResetting)
                .accessibilityLabel(
                    String(localized: "settings.reset.local.button.a11y",
                           defaultValue: "Reset local data. Destructive action.")
                )
            }

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
            String(localized: "settings.reset.sync.confirm.title",
                   defaultValue: "Reset iCloud Sync?"),
            isPresented: $showSyncReset,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.reset.sync.confirm.proceed",
                          defaultValue: "Reset iCloud Sync"), role: .destructive) {
                performSyncReset()
            }
            Button(String(localized: "settings.reset.cancel", defaultValue: "Cancel"),
                   role: .cancel) {}
        } message: {
            Text(String(localized: "settings.reset.sync.confirm.message",
                        defaultValue: "The local iCloud sync state will be cleared. Your data in iCloud is not deleted. The app will re-download your notes and collections on next launch."))
        }
        .confirmationDialog(
            String(localized: "settings.reset.local.confirm.title",
                   defaultValue: "Reset Local Data?"),
            isPresented: $showLocalReset,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.reset.local.confirm.proceed",
                          defaultValue: "Reset Local Data"), role: .destructive) {
                performLocalReset()
            }
            Button(String(localized: "settings.reset.cancel", defaultValue: "Cancel"),
                   role: .cancel) {}
        } message: {
            Text(String(localized: "settings.reset.local.confirm.message",
                        defaultValue: "Volume files and the search index will be deleted from this device. Your notes, collections, tags, and projects in iCloud are not affected and will re-sync."))
        }
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

    private func performSyncReset() {
        isResetting = true
        let fm = FileManager.default
        // Delete SwiftData SQLite files so the container re-downloads from CloudKit.
        let appSupportURLs = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        for base in appSupportURLs {
            // Standard SwiftData store location (bundle-id based)
            if let bundleId = Bundle.main.bundleIdentifier {
                let dir = base.appendingPathComponent(bundleId, isDirectory: true)
                if let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                    for file in files where file.pathExtension == "sqlite" {
                        try? fm.removeItem(at: file)
                    }
                }
            }
            // Also check the named app-support dir used by this app
            let namedDir = base.appendingPathComponent("FRUSExplorer", isDirectory: true)
            if let files = try? fm.contentsOfDirectory(at: namedDir, includingPropertiesForKeys: nil) {
                for file in files where file.pathExtension == "sqlite"
                                         && !file.lastPathComponent.hasPrefix("frus") {
                    try? fm.removeItem(at: file)
                }
            }
        }
        appState.hasCompletedOnboarding = false
        isResetting = false
    }

    /// Local-only reset: deletes downloaded volumes and the search index, leaving
    /// the local SwiftData store and iCloud-synced data untouched.
    private func performLocalReset() {
        isResetting = true
        Task {
            await ResetService.resetLocalData(appState: appState)
            await MainActor.run { isResetting = false }
        }
    }

    private func performReset() {
        isResetting = true
        resetError = nil
        Task {
            do {
                // Delete downloaded volumes and clear the search index.
                await ResetService.resetLocalData(appState: appState)
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
    @AppStorage(SettingsKeys.citationStyle) private var citationStyle: CitationStyle = .historyAtState
    @AppStorage(SettingsKeys.defaultDocumentMode) private var defaultDocumentMode: DefaultDocumentMode = .rememberLast
    @AppStorage(ChartSeriesPalette.storageKey) private var chartSeriesCount = ChartSeriesPalette.defaultCount
    #if os(iOS)
    @AppStorage(SettingsKeys.edgeTapNavigationEnabled) private var edgeTapNavigationEnabled = true
    #endif

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
                Stepper(value: $chartSeriesCount, in: ChartSeriesPalette.range) {
                    Text(String(format: String(localized: "settings.display.chartColors.value %lld",
                                               defaultValue: "Distinctly-colored volumes: %lld"),
                                Int64(chartSeriesCount)))
                }
            } header: {
                Text(String(localized: "settings.display.chartColors.header",
                            defaultValue: "Chart Colors"))
            } footer: {
                Text(String(localized: "settings.display.chartColors.footer",
                            defaultValue: "How many volumes appear as distinct colors in the Chronology and Corpus Analytics charts before the rest fold into a single “Other” series. Each chart can override this per view."))
            }

            Section {
                Picker(String(localized: "settings.display.citationStyle.label",
                              defaultValue: "Citation Style"),
                       selection: $citationStyle) {
                    ForEach(CitationStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .accessibilityLabel(
                    String(localized: "settings.display.citationStyle.a11y",
                           defaultValue: "Citation style")
                )
            } header: {
                Text(String(localized: "settings.display.citationStyle.header",
                            defaultValue: "Citations"))
            } footer: {
                Text(String(localized: "settings.display.citationStyle.footer",
                            defaultValue: "Used when copying or sharing a citation."))
            }

            Section {
                Picker(String(localized: "settings.display.defaultMode.label",
                              defaultValue: "Open Documents In"),
                       selection: $defaultDocumentMode) {
                    ForEach(DefaultDocumentMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .accessibilityLabel(
                    String(localized: "settings.display.defaultMode.a11y",
                           defaultValue: "Default document mode")
                )

                #if os(iOS)
                Toggle(
                    String(localized: "settings.display.edgeTapNavigation.label",
                           defaultValue: "Edge-Tap Page Turn"),
                    isOn: $edgeTapNavigationEnabled
                )
                .accessibilityHint(
                    String(localized: "settings.display.edgeTapNavigation.a11y",
                           defaultValue: "When on, tapping near the left or right edge in Read mode opens the previous or next document")
                )
                #endif
            } header: {
                Text(String(localized: "settings.display.reading.header",
                            defaultValue: "Reading"))
            } footer: {
                Text(String(localized: "settings.display.reading.footer",
                            defaultValue: "\"Remember Last\" reopens documents in whichever mode — Read or Research — you last used. Research mode shows the Research rail — a side panel on iPad, a bottom sheet on iPhone; Read mode hides it for distraction-free reading. The in-document rail toggle always overrides for the current document."))
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
    @AppStorage(SearchDefaults.scopeDocumentsKey) private var scopeDocuments    = true
    @AppStorage(SearchDefaults.scopeNotesKey)     private var scopeNotes        = true
    @AppStorage(SearchDefaults.scopeSummariesKey) private var scopeSummaries    = true
    @AppStorage(SearchDefaults.typeFilterKey)     private var defaultTypeFilter = "all"
    @AppStorage(SearchDefaults.snippetLineCountKey) private var snippetLineCount = SearchDefaults.defaultSnippetLineCount

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

            Section {
                Picker(String(localized: "settings.search.snippet.label",
                              defaultValue: "Snippet length"),
                       selection: $snippetLineCount) {
                    ForEach(1...10, id: \.self) { n in
                        Text(SearchDefaults.snippetLinesLabel(n)).tag(n)
                    }
                }
            } header: {
                Text(String(localized: "settings.search.snippet.header", defaultValue: "Result Preview"))
            } footer: {
                Text(String(localized: "settings.search.snippet.footer",
                            defaultValue: "How many lines of matched context each search result shows. Individual search screens can override this default."))
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
    /// UserDefaults key for the maximum simultaneous volume downloads.
    /// Written by the Downloads settings (both platforms), read at boot by
    /// `FRUSExplorerApp` and applied live via `DownloadManager.setConcurrencyLimit`.
    static let concurrentDownloadLimit = "frus.concurrentDownloadLimit"

    /// UserDefaults key for the persisted citation style (history.state.gov /
    /// Chicago / Turabian). Read via `CitationStyle.current`; drives
    /// `DocumentViewModel.formattedCitation` and friends, the iOS
    /// `CitationSheetView`, and the macOS citation popover's initial selection.
    static let citationStyle = "frus.citation.style"

    /// UserDefaults key (Bool, default `true`) controlling whether volume
    /// downloads may use cellular data. Read by `DownloadManager.processQueue()`
    /// and applied per-request via `URLRequest.allowsCellularAccess` — changing
    /// it only affects downloads started afterwards, not transfers already
    /// handed to the background session. iOS only; surfaced in the iOS
    /// Downloads settings "Settings" section (Session 154).
    static let allowCellularDownloads = "frus.downloads.allowCellular"

    /// UserDefaults key (Bool, default `true`) controlling whether the document
    /// reader's invisible leading/trailing edge-tap zones page through to the
    /// previous/next document while in Read mode. Read by
    /// `DocumentView.documentEdgeNavigationOverlay` (iOS only — macOS uses
    /// explicit prev/next chevron buttons instead). Surfaced in the "Reading"
    /// group of the iOS Display settings (Session 154).
    static let edgeTapNavigationEnabled = "frus.reading.edgeTapNavigation"

    /// UserDefaults key (`DefaultDocumentMode` raw value, default `"rememberLast"`)
    /// controlling which mode a document opens in: forced Read, forced Research,
    /// or remember the last choice (the pre-Session-154 behaviour, where
    /// `frus.document.researchPanel.visible` simply persists across documents).
    /// Applied once per document open by `DocumentView` (iOS) and
    /// `MacDocumentView` (macOS); the in-document Read/Research rail toggle
    /// still overrides live for that document. Surfaced in the
    /// "Reading" group of Display settings on both platforms (Session 154).
    static let defaultDocumentMode = "frus.reading.defaultMode"

    /// UserDefaults key (Bool, default `true`) controlling whether indexing
    /// progress requests a Live Activity (Dynamic Island / Lock Screen widget).
    /// Checked in `AppState.syncIndexingLiveActivity()` before
    /// `Activity<IndexingActivityAttributes>.request`; when off, any running
    /// activity is ended. iOS only; surfaced in the iOS Storage & Index
    /// settings, near the reindex controls (Session 154).
    static let liveActivityEnabled = "frus.indexing.liveActivityEnabled"
}

