// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import TipKit
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
/// The rows, their labels, icons, grouping, and order all come from the shared `SettingsPane`
/// model (S-1) — see `SettingsPaneModel.swift` for the tree, which is the same one the macOS
/// sidebar renders. This file supplies only the destination view for each pane, in
/// `settingsRow(for:)`. The hand-maintained table that used to sit here drifted from what shipped.
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
///   2.6 — S-2c: `DownloadsSettingsView`, `StorageManagementView`, and `SideloadView` (1,577
///          lines) leave this file for the merged `VolumesStorageHubView`; Library is one row.
///          The stale hand-copied panel table above is replaced by a pointer to the model
///   2.7 — Wave R-1: removed the orphaned `researchSessionLoggingEnabled` `@AppStorage`
///          property — the switch itself has lived in `ResearchSessionsView` since S-1 and
///          nothing in this file read the value
struct SettingsView: View {

    #if !os(iOS)
    @Environment(\.dismiss) private var dismiss
    #endif

    // The research-logging `@AppStorage` that used to sit here was removed in Wave R-1: the
    // switch moved to `ResearchSessionsView` in S-1 and nothing in this file had read the
    // property since. Leaving it behind made the key look like it had more readers than it did.

    /// Device-local master toggle for optional cross-device settings sync.
    @AppStorage(SettingsSyncCoordinator.enabledKey) private var syncSettingsEnabled = false

    /// Settings-search text (S-1). Matches panes through `SettingsPane.matches(_:)`, which reads
    /// the shared model's keywords — so "stop words" finds Word Cloud and "api key" finds NARA.
    @State private var paneQuery = ""
    @Environment(AppState.self) private var appState

    var body: some View {
        // The `@Bindable` shadow went with the Research Guide sheet (#752 / L-43) — it existed
        // only to spell `$appState.showResearchGuide`, and nothing in this body binds `appState`
        // any more. An unused one is a warning on a CLEAN build, which an incremental build will
        // not re-emit.
        NavigationStack {
            Form {
                // iCloud sync status — visible on iOS where there is no macOS status bar.
                // Shows container init result and the most recent sync event outcome.
                SyncSettingsSection { iCloudSyncStatusRow }

                // Rows come from the shared `SettingsPane` model (S-1) in the four task-first
                // groups, so this root and the macOS sidebar cannot disagree about a pane's name,
                // icon, or placement. `paneQuery` filters them through the model's keywords.
                ForEach(SettingsPane.groupedPanes(on: .iOS), id: \.group) { entry in
                    let visible = entry.panes.filter { $0.matches(paneQuery) }
                    if !visible.isEmpty {
                        Section(entry.group.label) {
                            ForEach(visible) { pane in
                                settingsRow(for: pane)
                            }
                        }
                    }
                }

                #if os(iOS) && DEBUG
                if paneQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section("Diagnostics") {
                        NavigationLink("Summarization Probe") {
                            SummarizationProbeView()
                        }
                    }
                }
                #endif
            }
            .navigationTitle(String(localized: "settings.title", defaultValue: "Settings"))
            #if os(iOS)
            .searchable(text: $paneQuery,
                        placement: .navigationBarDrawer(displayMode: .automatic),
                        prompt: Text(String(localized: "settings.search.prompt",
                                            defaultValue: "Search Settings")))
            #endif
            // HIG: top-level destination screens use .large title to match system weight.
            // Child panes (the Volumes & Storage hub, Tags, Display, etc.) keep .inline.
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
            // The Research Guide sheet moved to `AboutView`, which owns the row that opens it
            // (#752 / L-43). Presenting it here off an `AppState` flag meant every open iPad
            // window's Settings tab was bound to the same Bool.
        }
        #if os(macOS)
        // Provides stable minimum dimensions for the settings sheet on macOS so that
        // NavigationLink destinations inherit a proper sized container and render correctly.
        .frame(minWidth: 500, minHeight: 440)
        #endif
    }

    // MARK: - Pane Rows

    /// The row for one shared-model pane, with its destination.
    ///
    /// The label and icon come from `SettingsPane` so they cannot drift from the macOS sidebar;
    /// only the destination view is platform-local. A pane whose `platforms` excludes iOS never
    /// reaches here, so the `EmptyView` arms are unreachable by construction.
    @ViewBuilder
    private func settingsRow(for pane: SettingsPane) -> some View {
        switch pane {
        case .volumesStorage:
            // `VolumesStorageHubView` is iOS-only (it is built from `.swipeActions`,
            // `.navigationBarTitleDisplayMode`, the Live Activity toggle, and other UIKit-side
            // idioms). This whole root only ever renders inside `MainTabView`, which is the iOS
            // layout — macOS uses `FRUSSettingsView` — but the file itself compiles for both.
            #if os(iOS)
            NavigationLink { VolumesStorageHubView() } label: { paneLabel(pane) }
            #else
            EmptyView()
            #endif
        case .projects:
            NavigationLink { ProjectsSettingsView() } label: { paneLabel(pane) }
        case .tags:
            NavigationLink { UserTagsView() } label: { paneLabel(pane) }
        case .scopes:
            NavigationLink { CustomScopesView() } label: { paneLabel(pane) }
        case .workingCorpora:
            NavigationLink { WorkingCorporaView() } label: { paneLabel(pane) }
        case .summarization:
            NavigationLink { SummarizationPromptsSettingsView() } label: { paneLabel(pane) }
        case .wordCloud:
            NavigationLink { WordCloudSettingsView() } label: { paneLabel(pane) }
        case .display:
            NavigationLink { DisplaySettingsView() } label: { paneLabel(pane) }
        case .search:
            NavigationLink { SearchDefaultsView() } label: { paneLabel(pane) }
        case .connections:
            NavigationLink { ConnectionsView() } label: { paneLabel(pane) }
        case .dataRecovery:
            NavigationLink { DataRecoveryView() } label: { paneLabel(pane) }
        case .about:
            NavigationLink { AboutView() } label: { paneLabel(pane) }
        case .notes:
            NavigationLink { NotesSettingsView() } label: { paneLabel(pane) }
        case .researchSessions:
            NavigationLink { ResearchSessionsView() } label: { paneLabel(pane) }
        // macOS-only pane (see `SettingsPane.platforms`): iOS renders sync as the inline section
        // at the top of this root, not as a pushed destination.
        case .sync:
            EmptyView()
        }
    }

    /// One row label, icon and title straight from the shared model.
    private func paneLabel(_ pane: SettingsPane) -> some View {
        Label(pane.label, systemImage: pane.icon)
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
                    // "Reset iCloud Sync below" named a control that no longer exists — the
                    // recovery ladder moved into Data & Recovery in S-4b and the rung is called
                    // "Fix iCloud Sync". Both platforms now name the one true path.
                    detail: String(localized: "settings.icloud.zoneMissing.detail",
                                   defaultValue: "The iCloud sync zone is missing. Data cannot upload or download until it is recreated. Force-quit and relaunch the app, or use Settings → Data & Recovery → Fix iCloud Sync.")
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
            // Match downloaded volumes: keep the XML out of iCloud Backup / Time Machine, since
            // it is re-obtainable and bulky. The old macOS sideload path set this and the
            // validator did not, so which of the two you used decided whether your copy got
            // backed up (S-2b routed macOS through the validator, so it belongs here now).
            try? (dest as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
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

// MARK: - UserTagsView

/// iOS Settings → Research → Tags — the list, in the shared row grammar (S-3b).
///
/// Every row states what the tag is attached to and opens `TagEditorView`, where rename, merge and
/// delete are visible rows with footers that say what each costs. The swipes survive as shortcuts
/// for people who already know them, but nothing is *only* reachable by gesture any more — the old
/// footer that had to teach them ("Tap or swipe right to rename. Swipe left to delete.") is gone,
/// and so is the tap-to-rename mode that made a plain tap destructive-adjacent.
///
/// Version history:
///   1.0 — Session 24: initial implementation
///   1.1 — S-3a: rows carry their attachment tally; merge moved to `UserTagAdmin`
///   1.2 — S-3b: row → editor; "New Tag…" ends the list; the empty state says where tags come from
private struct UserTagsView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserTag.name) private var tags: [UserTag]

    /// The tag open in the editor sheet.
    @State private var editingTag: UserTag? = nil
    /// The tag whose merge picker the host is presenting.
    @State private var mergingTag: UserTag? = nil
    /// A freshly created tag, opened straight into the editor so it can be named.
    @State private var pendingNewTag: UserTag? = nil
    /// How much is attached to each tag, fetched once per appearance rather than per row.
    @State private var counts: ResearchItemCounts = .empty

    var body: some View {
        Form {
            Section {
                if tags.isEmpty {
                    Text(String(localized: "settings.tags.empty.where",
                                defaultValue: "No tags yet. Tags are the labels you apply to research notes and documents as you read — create one here, or from any note."))
                        .foregroundStyle(.secondary)
                        .font(.callout)
                } else {
                    ForEach(tags) { tag in
                        Button {
                            editingTag = tag
                        } label: {
                            HStack {
                                SettingsNavRow(label: tag.name, detail: counts.tag(tag.id).summary)
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        // Swipes stay as shortcuts — everything they do is also a row in the editor.
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                UserTagAdmin.deleteCascading(tag, context: modelContext)
                                counts = ResearchItemCounts.fetch(from: modelContext)
                            } label: {
                                Label(String(localized: "settings.tags.delete.swipe",
                                             defaultValue: "Delete"), systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                editingTag = tag
                            } label: {
                                Label(String(localized: "settings.tags.rename.swipe",
                                             defaultValue: "Edit"), systemImage: "pencil")
                            }
                            .tint(.accentColor)
                        }
                    }
                }

                SettingsNewItemRow(label: String(localized: "settings.tags.new",
                                                 defaultValue: "New Tag…")) {
                    let tag = UserTag(name: String(localized: "settings.tags.new.default",
                                                   defaultValue: "New Tag"))
                    modelContext.insert(tag)
                    pendingNewTag = tag
                }
            } header: {
                Text(String(localized: "settings.tags.list.header", defaultValue: "Tags"))
            } footer: {
                Text(String(localized: "settings.tags.list.footer.grammar",
                            defaultValue: "Tags are global — they are not scoped to a project."))
            }
        }
        .navigationTitle(String(localized: "settings.tags.title", defaultValue: "Tags"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { counts = ResearchItemCounts.fetch(from: modelContext) }
        .sheet(item: $editingTag) { tag in
            TagEditorView(
                tag: tag,
                tally: counts.tag(tag.id),
                peerTagCount: tags.count,
                onMergeRequested: { source in mergingTag = source },
                onDeleted: { counts = ResearchItemCounts.fetch(from: modelContext) }
            )
        }
        .sheet(item: $pendingNewTag) { tag in
            // A new tag opens straight into the editor so it can be named; Merge and Delete are
            // hidden, because neither makes sense before it has been named or used.
            TagEditorView(tag: tag)
        }
        .sheet(item: $mergingTag) { sourceTag in
            MergeTagSheet(
                sourceTag: sourceTag,
                allTags: tags.filter { $0.id != sourceTag.id },
                onMerge: { targetTag in
                    UserTagAdmin.merge(sourceTag, into: targetTag, context: modelContext)
                    mergingTag = nil
                    counts = ResearchItemCounts.fetch(from: modelContext)
                }
            )
        }
    }
}

// MARK: - ProjectsSettingsView

/// iOS Settings → Research → Projects — the hub for the research trio (S-3b).
///
/// ## Shape
/// Context first, admin second, siblings last:
///
/// 1. **Active Project** + **Project Home**, pinned as their own group. Switching context is the
///    thing a reader does most often here and it is not destructive; keeping it away from rename,
///    merge and delete means a mis-tap can't be expensive.
/// 2. **Projects** — one row each, stating what is filed under it, opening the editor. "New
///    Project…" ends the list.
/// 3. **Related** — Tags and Volume Scopes, with their counts. The three lists share one grammar,
///    so the two siblings are reachable from the one a reader lands on.
///
/// Rename, merge and delete used to be a tap, a long-press and a swipe respectively, explained by a
/// footer. They are now rows in `ProjectEditorView`; the swipes remain as shortcuts.
///
/// Version history:
///   1.0 — Session 153: initial implementation (closes the iOS delete/merge gap)
///   1.1 — #377 Phase 5 follow-up: New Project toolbar button (iOS project creation)
///   1.2 — S-3b: row → editor, counts on rows, "New Project…" ends the list, Related group
private struct ProjectsSettingsView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.name) private var projects: [Project]
    @Query(sort: \UserTag.name) private var tags: [UserTag]
    @Query(sort: \CustomVolumeScope.name) private var scopes: [CustomVolumeScope]
    @Query(sort: \WorkingCorpus.name) private var workingCorpora: [WorkingCorpus]

    /// The project open in the editor sheet.
    @State private var editingProject: Project? = nil
    /// The project whose merge picker is presented.
    @State private var mergingProject: Project? = nil
    /// Presents `ProjectEditorView` in create mode.
    @State private var showEditor = false
    /// How much is filed under each project, fetched once per appearance rather than per row.
    @State private var counts: ResearchItemCounts = .empty

    var body: some View {
        Form {
            // 1. Context — the non-destructive half, pinned above the admin list.
            Section {
                Picker(selection: Binding(get: { appState.activeProjectId },
                                          set: { appState.activeProjectId = $0 })) {
                    Text(String(localized: "settings.projects.active.global",
                                defaultValue: "Global Context")).tag(UUID?.none)
                    ForEach(projects) { project in
                        Text(project.name).tag(UUID?.some(project.id))
                    }
                } label: {
                    Label(String(localized: "settings.projects.active.label",
                                 defaultValue: "Active Project"),
                          systemImage: appState.activeProjectId == nil ? "globe" : "folder")
                }

                if let pid = appState.activeProjectId, projects.contains(where: { $0.id == pid }) {
                    NavigationLink {
                        ProjectHomeView(projectId: pid)
                    } label: {
                        Label(String(localized: "settings.projects.home",
                                     defaultValue: "Project Home"),
                              systemImage: "square.grid.2x2")
                    }
                }
            } footer: {
                Text(String(localized: "settings.projects.active.footer",
                            defaultValue: "The active project scopes the notes, collections, history, and searches you see. Global Context shows everything."))
            }

            // 2. The list itself.
            Section {
                if projects.isEmpty {
                    Text(String(localized: "settings.projects.empty.where",
                                defaultValue: "No projects yet. A project keeps one line of research — its notes, collections, history and searches — separate from the rest."))
                        .foregroundStyle(.secondary)
                        .font(.callout)
                } else {
                    ForEach(projects) { project in
                        Button {
                            editingProject = project
                        } label: {
                            HStack {
                                SettingsNavRow(label: project.name, detail: rowDetail(project))
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            // Without this the row is only tappable where its glyphs are — the
                            // whole row has to be the target, or the grammar is a lie.
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                ProjectAdminService.delete(project, context: modelContext,
                                                           appState: appState)
                                counts = ResearchItemCounts.fetch(from: modelContext)
                            } label: {
                                Label(String(localized: "settings.projects.delete.swipe",
                                             defaultValue: "Delete"), systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                editingProject = project
                            } label: {
                                Label(String(localized: "settings.projects.rename.swipe",
                                             defaultValue: "Edit"), systemImage: "pencil")
                            }
                            .tint(.accentColor)
                        }
                    }
                }

                SettingsNewItemRow(label: String(localized: "settings.projects.new",
                                                 defaultValue: "New Project…")) {
                    showEditor = true
                }
            } header: {
                Text(String(localized: "settings.projects.list.header", defaultValue: "All Projects"))
            }

            // 3. The two lists that share this grammar.
            Section {
                NavigationLink {
                    UserTagsView()
                } label: {
                    SettingsNavRow(label: String(localized: "settings.pane.tags", defaultValue: "Tags"),
                                   systemImage: "tag",
                                   detail: tagsDetail)
                }
                NavigationLink {
                    CustomScopesView()
                } label: {
                    SettingsNavRow(label: String(localized: "settings.pane.scopes",
                                                 defaultValue: "Volume Scopes"),
                                   systemImage: "square.stack.3d.up",
                                   detail: scopesDetail)
                }
                NavigationLink {
                    WorkingCorporaView()
                } label: {
                    SettingsNavRow(label: String(localized: "settings.pane.workingCorpora",
                                                 defaultValue: "Working Corpora"),
                                   systemImage: "tray.full",
                                   detail: workingCorporaDetail)
                }
            } header: {
                Text(String(localized: "settings.projects.related.header", defaultValue: "Related"))
            } footer: {
                Text(String(localized: "settings.projects.related.footer",
                            defaultValue: "Open Tags to rename, merge or delete a tag. Open Volume Scopes to edit or delete a scope — scopes cannot be merged."))
            }
        }
        .navigationTitle(String(localized: "settings.projects.title", defaultValue: "Projects"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { counts = ResearchItemCounts.fetch(from: modelContext) }
        .sheet(isPresented: $showEditor) {
            // Create mode. Re-inject AppState: ProjectEditorView reads it for the #377 Phase-5
            // second-project nudge signal, and a sheet doesn't reliably inherit it.
            ProjectEditorView(projectToEdit: nil,
                              onSaved: { counts = ResearchItemCounts.fetch(from: modelContext) })
                .environment(appState)
        }
        .sheet(item: $editingProject) { project in
            ProjectEditorView(
                projectToEdit: project,
                onSaved: { counts = ResearchItemCounts.fetch(from: modelContext) },
                onMergeRequested: { source in mergingProject = source },
                onDeleted: { counts = ResearchItemCounts.fetch(from: modelContext) },
                peerProjectCount: projects.count
            )
            .environment(appState)
        }
        .sheet(item: $mergingProject) { sourceProject in
            MergeProjectSheet(
                sourceProject: sourceProject,
                allProjects: projects.filter { $0.id != sourceProject.id },
                onMerge: { targetProject in
                    ProjectAdminService.merge(sourceProject, into: targetProject,
                                              context: modelContext, appState: appState)
                    mergingProject = nil
                    counts = ResearchItemCounts.fetch(from: modelContext)
                }
            )
        }
    }

    // MARK: - Row detail

    /// "12 notes · 3 collections · active" — what is filed under the project, and whether it is the
    /// one currently scoping the app.
    private func rowDetail(_ project: Project) -> String {
        var line = counts.project(project.id).summary
        if appState.activeProjectId == project.id {
            line += " · " + String(localized: "settings.projects.row.active", defaultValue: "active")
        }
        if let question = project.researchQuestion, !question.isEmpty {
            line += "\n" + question
        }
        return line
    }

    private var tagsDetail: String {
        tags.isEmpty
            ? String(localized: "settings.projects.related.tags.none", defaultValue: "None yet")
            : (tags.count == 1
               ? String(localized: "settings.projects.related.tags.one", defaultValue: "1 tag")
               : String(format: String(localized: "settings.projects.related.tags.many %lld",
                                       defaultValue: "%lld tags"), Int64(tags.count)))
    }

    /// The corpora row's detail: how many, and how many this device cannot fully reach.
    private var workingCorporaDetail: String {
        guard !workingCorpora.isEmpty else {
            return String(localized: "settings.projects.related.scopes.none", defaultValue: "None yet")
        }
        let resolver = WorkingCorpusResolver(indexedVolumeIds: appState.indexedVolumeIds)
        let partial = workingCorpora.filter { !resolver.resolve($0).isComplete }.count
        guard partial > 0 else {
            return String(format: String(localized: "settings.corpora.detail %lld",
                                         defaultValue: "%lld"), Int64(workingCorpora.count))
        }
        return String(format: String(localized: "settings.corpora.detail.partial %lld %lld",
                                     defaultValue: "%lld · %lld partly indexed"),
                      Int64(workingCorpora.count), Int64(partial))
    }

    private var scopesDetail: String {
        guard !scopes.isEmpty else {
            return String(localized: "settings.projects.related.scopes.none", defaultValue: "None yet")
        }
        let unindexed = scopes.filter {
            CustomScopeResolver.indexedResolution(memberVolumeIds: $0.volumeIds,
                                                  indexed: appState.indexedVolumeIds)
                == .noIndexedMembers
        }.count
        let base = scopes.count == 1
            ? String(localized: "settings.projects.related.scopes.one", defaultValue: "1 scope")
            : String(format: String(localized: "settings.projects.related.scopes.many %lld",
                                    defaultValue: "%lld scopes"), Int64(scopes.count))
        guard unindexed > 0 else { return base }
        return base + " · " + String(format: String(
            localized: "settings.projects.related.scopes.unindexed %lld",
            defaultValue: "%lld not yet indexed"), Int64(unindexed))
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

/// iOS Settings → Research → Summarization (S-3d).
///
/// ## Availability first, receipt last
/// The pane answers two questions without anyone keeping a progress screen open: *can it work?* —
/// the Apple Intelligence row at the top — and *did it work?* — the Last run row at the bottom.
/// Between them sit the prompts, which are the pane's one job.
///
/// The batch-run form used to live here, embedded below the prompt lists and (on this platform)
/// nested inside another `Section`, which is malformed. It is now a door: "New Batch Run…" opens
/// `BatchRunSheet`. The pane stopped having two jobs, and a running batch's progress ticks stopped
/// re-rendering the prompt list.
///
/// Version history:
///   1.0 — Session 20: initial implementation
///   1.1 — S-3d: availability row, run form moves to a sheet, per-prompt counts come from a
///          one-shot `PromptSummaryTally` rather than a per-row scan of every summary
private struct SummarizationPromptsSettingsView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SummarizationPrompt.createdAt) private var allPrompts: [SummarizationPrompt]

    /// Non-nil when editing an existing user prompt.
    @State private var editingPrompt: SummarizationPrompt? = nil
    /// Controls the new-prompt creation sheet.
    @State private var showNewPromptSheet: Bool = false
    /// When set, the new-prompt sheet opens pre-populated from this template
    /// (used by "Use as Template" on standard prompts and "Duplicate" on user prompts).
    @State private var newPromptInitialTemplate: PromptTemplate? = nil
    /// Controls the batch-run sheet.
    @State private var showRunSheet = false
    /// Per-prompt summary counts, tallied once per appearance rather than per row.
    @State private var tally: PromptSummaryTally = .empty

    var body: some View {
        Form {
            availabilitySection
            promptsSection
            generateSection
        }
        .navigationTitle(String(localized: "settings.pane.summarization",
                                defaultValue: "Summarization"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { tally = SummarizationPaneTally.fetch(from: modelContext) }
        .sheet(item: $editingPrompt, onDismiss: refreshTally) { prompt in
            PromptEditorView(promptToEdit: prompt)
        }
        .sheet(isPresented: $showNewPromptSheet, onDismiss: {
            newPromptInitialTemplate = nil
            refreshTally()
        }) {
            PromptEditorView(initialTemplate: newPromptInitialTemplate)
        }
        .sheet(isPresented: $showRunSheet, onDismiss: refreshTally) {
            BatchRunSheet().environment(appState)
        }
    }

    private func refreshTally() {
        tally = SummarizationPaneTally.fetch(from: modelContext)
    }

    // MARK: - Availability

    @ViewBuilder
    private var availabilitySection: some View {
        Section {
            if AppleIntelligenceProvider.shared.isAvailable {
                SettingsStatusRow(
                    label: String(localized: "settings.summarization.availability.label",
                                  defaultValue: "Apple Intelligence"),
                    detail: String(localized: "settings.summarization.availability.ready",
                                   defaultValue: "Ready — summaries generate on this device."),
                    state: .ok
                )
            } else {
                SettingsStatusRow(
                    label: String(localized: "settings.summarization.availability.label",
                                  defaultValue: "Apple Intelligence"),
                    detail: String(localized: "settings.summarization.availability.unavailable",
                                   defaultValue: "Not available on this device. Prompts still edit and sync to your other devices, where they are used for generation."),
                    state: .warning
                )
            }
        }
    }

    // MARK: - Prompts

    @ViewBuilder
    private var promptsSection: some View {
        let standard = allPrompts.filter { $0.isStandard }
        let user = allPrompts.filter { !$0.isStandard }

        if !standard.isEmpty {
            Section {
                ForEach(standard) { prompt in
                    HStack {
                        SettingsNavRow(label: prompt.name, detail: tally.rowSummary(for: prompt.id))
                        Spacer(minLength: 8)
                        Button {
                            newPromptInitialTemplate = templateFrom(prompt)
                            showNewPromptSheet = true
                        } label: {
                            Text(String(localized: "settings.summarization.useAsTemplate",
                                        defaultValue: "Use as Template"))
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(
                            String(localized: "settings.summarization.useAsTemplate.a11y",
                                   defaultValue: "Use \(prompt.name) as a template for a new prompt")
                        )
                    }
                }
            } header: {
                Text(String(localized: "settings.summarization.standard.header",
                            defaultValue: "Standard Prompts"))
            } footer: {
                Text(String(localized: "settings.summarization.standard.footer",
                            defaultValue: "The prompts the app ships with. They can't be edited — start from one with Use as Template."))
            }
        }

        Section {
            if user.isEmpty {
                Text(String(localized: "settings.summarization.user.empty.where",
                            defaultValue: "No prompts of your own yet. Prompts you create appear here and sync to your other devices via iCloud."))
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(user) { prompt in
                    Button {
                        editingPrompt = prompt
                    } label: {
                        HStack {
                            SettingsNavRow(label: prompt.name,
                                           detail: tally.rowSummary(for: prompt.id))
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    // Swipes stay as shortcuts; everything they do is also reachable from the row.
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
                    refreshTally()
                }
            }

            SettingsNewItemRow(label: String(localized: "settings.summarization.newPrompt",
                                             defaultValue: "New Prompt…")) {
                newPromptInitialTemplate = nil
                showNewPromptSheet = true
            }
        } header: {
            Text(String(localized: "settings.summarization.user.header",
                        defaultValue: "Your Prompts"))
        }
    }

    // MARK: - Generate

    @ViewBuilder
    private var generateSection: some View {
        let runState = appState.backgroundSummarizationProgress.state
        Section {
            Button {
                showRunSheet = true
            } label: {
                SettingsNavRow(
                    label: String(localized: "settings.summarization.newRun",
                                  defaultValue: "New Batch Run…"),
                    systemImage: "sparkles",
                    detail: String(localized: "settings.summarization.newRun.detail",
                                   defaultValue: "Scope, prompt and progress.")
                )
            }
            .buttonStyle(.plain)

            SettingsNavRow(
                label: String(localized: "settings.summarization.generated",
                              defaultValue: "Generated so far"),
                value: "\(tally.documentSummaries)"
            )

            SettingsStatusRow(
                label: String(localized: "settings.summarization.lastRun",
                              defaultValue: "Last run"),
                detail: BatchRunReceipt.text(for: runState),
                state: BatchRunReceipt.isFailure(runState)
                    ? .error
                    : (BatchRunReceipt.isCancelled(runState) ? .warning : .ok)
            )
        } header: {
            Text(String(localized: "settings.summarization.generate.header",
                        defaultValue: "Generate"))
        } footer: {
            Text(headnoteFooter)
        }
    }

    /// The count's caveat. Headnote drafts are `GeneratedSummary` rows too but are excluded from
    /// every summary query in the app, so the figure above counts document summaries only — and
    /// says so when there are drafts that would otherwise appear to be missing from it.
    private var headnoteFooter: String {
        let base = String(localized: "settings.summarization.generate.footer",
                          defaultValue: "Runs continue in the background if you allow it — set per run.")
        guard tally.headnoteDrafts > 0 else { return base }
        let drafts = tally.headnoteDrafts == 1
            ? String(localized: "settings.summarization.headnotes.one",
                     defaultValue: "1 collection headnote draft isn't counted above.")
            : String(format: String(localized: "settings.summarization.headnotes.many %lld",
                                    defaultValue: "%lld collection headnote drafts aren't counted above."),
                     Int64(tally.headnoteDrafts))
        return base + " " + drafts
    }

    // MARK: - Helpers

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
}

// MARK: - EraseEverythingView

/// The last rung of the recovery ladder, on its own screen with two confirmations (S-4b).
///
/// The two lighter repairs — Fix iCloud Sync and Reset This Device — moved onto the Data & Recovery
/// door itself, where a reader scanning for the smallest thing that might help meets them first.
/// This one is deliberately further away: it is the only one that destroys work.
///
/// Version history:
///   1.0 — Session 24: initial implementation as `ResetView`, all three rungs
///   1.1 — S-4b: reduced to the full erase; the two non-destructive rungs live on the door
///   1.2 — Wave R-5: the warning names the research trail. `performReset` has deleted it since
///          R-2a, but the copy still listed only notes/projects/tags/collections/highlights/
///          summaries, so the screen under-stated its own reach. New key (`…warning.trail`)
struct EraseEverythingView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var showFirstConfirmation  = false
    @State private var showSecondConfirmation = false
    @State private var isResetting = false
    @State private var resetError: String? = nil

    var body: some View {
        Form {
            Section {
                // New key for Wave R-5 (`…warning.trail`). R-2a extended `performReset` below to
                // delete the whole research trail, and this list — the screen's entire account of
                // what is about to go — was not updated with it. A destructive action that
                // under-states its reach is the same fault the wave exists to fix, one screen
                // over. Rewriting `settings.erase.warning` in place would be a silent collision:
                // no String Catalog ships.
                // #746 supersedes `…warning.trail`: that key was itself written because the
                // list under-stated its reach after Wave R-2a, and the audit then found five more
                // synced types the screen never mentioned because the code never deleted them.
                // New key rather than an in-place edit, for the same reason R-5 minted the last
                // one — no String Catalog ships, so rewriting a key in place is a silent
                // collision. The retention is stated too: a promise with an unlisted exception is
                // the fault this screen keeps repeating.
                // Archive Visits Phase 2 supersedes `…warning.inventory` in turn: the reset now
                // reaches archive visit plans, and a destructive screen that under-states its
                // reach is this screen's recurring fault — so the list is extended and, per the
                // standing rule, the key is minted anew rather than rewritten in place.
                Text(String(localized: "settings.erase.warning.inventory.visits",
                            defaultValue: "This deletes every downloaded volume and the search index. It deletes all of your research notes, projects, tags, collections, highlights, and AI-generated summaries. It also deletes your saved searches, working corpora, custom volume scopes, archive visit plans, project leads, and any person-identity corrections you have made. It deletes your whole research trail as well: every document you opened, every search you ran, and every collection you exported. Because your research data syncs, it goes from your other devices too. Your app preferences are kept. This cannot be undone."))
                    .foregroundStyle(.secondary)
            } header: {
                Text(String(localized: "settings.erase.header", defaultValue: "What This Removes"))
            }

            Section {
                Button(role: .destructive) {
                    showFirstConfirmation = true
                } label: {
                    if isResetting {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(String(localized: "settings.erase.working", defaultValue: "Erasing…"))
                        }
                    } else {
                        Text(String(localized: "settings.erase.button",
                                    defaultValue: "Erase Everything…"))
                    }
                }
                .disabled(isResetting)

                if let resetError {
                    Label(resetError, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            } footer: {
                Text(String(localized: "settings.erase.footer",
                            defaultValue: "You will be asked twice. Afterwards the app returns to onboarding as if newly installed."))
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .navigationTitle(String(localized: "settings.dataRecovery.erase",
                                defaultValue: "Erase Everything…"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .confirmationDialog(
            String(localized: "settings.erase.confirm1.title",
                   defaultValue: "Erase everything?"),
            isPresented: $showFirstConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.erase.confirm1.proceed",
                          defaultValue: "Continue"), role: .destructive) {
                showSecondConfirmation = true
            }
            Button(String(localized: "settings.connections.cancel", defaultValue: "Cancel"),
                   role: .cancel) {}
        } message: {
            Text(String(localized: "settings.erase.confirm1.message",
                        defaultValue: "Everything listed above will be deleted from this device and from iCloud."))
        }
        .confirmationDialog(
            String(localized: "settings.erase.confirm2.title",
                   defaultValue: "This cannot be undone"),
            isPresented: $showSecondConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.erase.confirm2.proceed",
                          defaultValue: "Erase Everything"), role: .destructive) {
                performReset()
            }
            Button(String(localized: "settings.connections.cancel", defaultValue: "Cancel"),
                   role: .cancel) {}
        } message: {
            Text(String(localized: "settings.erase.confirm2.message",
                        defaultValue: "Export your research data first if you might want it back."))
        }
    }

    private func performReset() {
        isResetting = true
        resetError = nil
        Task {
            do {
                // Delete downloaded volumes and clear the search index.
                await ResetService.resetLocalData(appState: appState)
                // Delete every SwiftData type `ResetInventory.erased` names, in its order —
                // dependents before the records they reference, because this sequence is not
                // transactional (an interrupted reset should leave a harmless orphaned child, not
                // a dangling reference to a deleted parent). The list moved out of this function
                // in #746: spelled out inline it fell behind `frusModelTypes` twice, most
                // recently leaving five CloudKit-synced user-data types alive under a screen that
                // promises the app "returns to onboarding as if newly installed".
                // `ResetInventoryTests` fails the moment a new `@Model` is enrolled without a
                // decision recorded here.
                for modelType in ResetInventory.erased {
                    try modelContext.delete(model: modelType)
                }
                await MainActor.run {
                    appState.activeProjectId = nil
                    appState.hasCompletedOnboarding = false
                    appState.hasFinishedOnboardingWithoutVolumes = false
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

// MARK: - SyncSettingsSection

/// The iCloud Sync section — the device-local master switch for cross-device settings sync.
///
/// One declaration, two hosts (S-5b): a section of the iOS Settings root, and the whole of the
/// macOS Sync pane. Before this the two kept private copies of the same four sentences and had
/// already drifted — the Mac said "shares those settings", iOS "shares the settings above", and
/// `Docs/EditableContent.md` claimed all three keys were a "single edit point" when they were
/// not. `leading` lets iOS put its sync-status row inside the same section; macOS shows status
/// in the main window's status bar and passes nothing.
///
/// Version history:
///   1.0 — S-5b: extracted from `SettingsView` so `SettingsSyncPane` could be deleted
struct SyncSettingsSection<Leading: View>: View {

    /// Rows shown above the toggle — the iOS sync-status cell, or nothing.
    @ViewBuilder var leading: Leading

    /// Whether to draw the "iCloud Sync" section header. False on the macOS pane, where the
    /// window already carries that title and a header would stutter it.
    var showsHeader: Bool = true

    @AppStorage(SettingsSyncCoordinator.enabledKey) private var syncSettingsEnabled = false
    @Environment(AppState.self) private var appState

    var body: some View {
        if showsHeader {
            Section {
                rows
            } header: {
                Text(String(localized: "settings.section.icloud", defaultValue: "iCloud Sync"))
            } footer: {
                footerText
            }
        } else {
            Section {
                rows
            } footer: {
                footerText
            }
        }
    }

    @ViewBuilder
    private var rows: some View {
        Group {
            leading
            Toggle(isOn: $syncSettingsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "settings.sync.toggle",
                                defaultValue: "Sync Settings Across Devices"))
                    Text(String(localized: "settings.sync.toggle.detail",
                                defaultValue: "Word-cloud filters & stop lists, citation style, default document mode, and research logging."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var footerText: Text {
        Text(String(localized: "settings.sync.footer",
                    defaultValue: "When this is on, the device shares the settings above with your other devices that also have it on. Turning it on adopts the settings already in iCloud. Leave it off to keep this device's settings separate."))
    }
}

extension SyncSettingsSection where Leading == EmptyView {
    /// The section with no leading rows — the macOS pane, which gets its sync status from the
    /// main window's status bar rather than repeating it here.
    init(showsHeader: Bool = true) {
        self.init(leading: { EmptyView() }, showsHeader: showsHeader)
    }
}

#if os(macOS)
/// The macOS Settings → iCloud Sync pane: the shared section, in a Form of its own.
///
/// Version history:
///   1.0 — S-5b: replaces the hand-rolled `SettingsSyncPane`
struct SyncSettingsView: View {
    var body: some View {
        Form {
            SyncSettingsSection(showsHeader: false)
        }
        .formStyle(.grouped)
        .navigationTitle(String(localized: "settings.pane.sync", defaultValue: "iCloud Sync"))
        .frame(maxWidth: .infinity)
        .scrollIndicators(.visible)
    }
}
#endif

// MARK: - DisplaySettingsView

/// The Display pane — text size, chart colors, citation style, and reading defaults.
///
/// Shared by both platforms since S-5b. macOS had a parallel `SettingsDisplayPane` that had
/// drifted from this one in section order and in three footer sentences; it is gone. The
/// controls a platform doesn't have (edge-tap page turn) stay behind their own fence, and the
/// one sentence that is genuinely macOS-only — the citation popover — is a separate key rather
/// than the same key with two texts, which would be a silent collision.
///
/// Version history:
///   1.0 — Session 26: iOS Display settings
///   1.1 — S-5b: shared with macOS; `SettingsDisplayPane` deleted
struct DisplaySettingsView: View {
    @AppStorage("frus.display.textSize") private var textSize: TextSizePreference = .medium
    @AppStorage(SettingsKeys.citationStyle) private var citationStyle: CitationStyle = .historyAtState
    @AppStorage(SettingsKeys.defaultDocumentMode) private var defaultDocumentMode: DefaultDocumentMode = .rememberLast
    @AppStorage(ChartSeriesPalette.storageKey) private var chartSeriesCount = ChartSeriesPalette.defaultCount
    #if os(iOS)
    @AppStorage(SettingsKeys.edgeTapNavigationEnabled) private var edgeTapNavigationEnabled = true
    #endif

    /// Set once the reset has run, so the button reads as having done something.
    ///
    /// Deliberately view state and not persisted: it acknowledges *this* tap. A tip that has been
    /// re-armed and not yet re-seen is not a state Settings should keep describing on the next
    /// visit, and the honest confirmation is the tip itself reappearing.
    @State private var didResetTips = false

    /// Re-arms every discovery tip. See ``DiscoveryTipRegistry/resetAll()``.
    private func resetDiscoveryTips() {
        didResetTips = true
        Task { await DiscoveryTipRegistry.resetAll() }
    }

    /// Whether this is an iPhone. The "Open Documents In" default is offered only where passive
    /// Research mode is usable — the iPad/Mac side panel. On iPhone the rail is a user-triggered
    /// bottom sheet (#404), so a "Research" default would have nothing to act on; the picker is
    /// hidden there and the mode setting simply doesn't apply.
    private var isPhone: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

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
                // The citation popover is a macOS surface (`CitationPopoverView`), so only the
                // Mac footer may promise it. Same key with two texts would be the silent
                // collision the localized-key lesson warns about.
                #if os(macOS)
                Text(String(localized: "settings.display.citationStyle.footer.mac",
                            defaultValue: "Used for Copy Citation, Share Citation, and the citation popover's default. The popover can still switch styles per-presentation for comparison."))
                #else
                Text(String(localized: "settings.display.citationStyle.footer",
                            defaultValue: "Used when copying or sharing a citation."))
                #endif
            }

            Section {
                // #404: the "Open Documents In" default applies only where passive Research mode is
                // usable — the iPad/Mac side panel. On iPhone the rail is a user-triggered bottom
                // sheet, so a Research default would have no effect; the picker is hidden there.
                if !isPhone {
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
                }

                #if os(iOS)
                Toggle(
                    String(localized: "settings.display.edgeTapNavigation.label",
                           defaultValue: "Edge-Tap Page Turn"),
                    isOn: $edgeTapNavigationEnabled
                )
                .accessibilityHint(
                    String(localized: "settings.display.edgeTapNavigation.a11y",
                           defaultValue: "When on, tapping near the left or right edge of a document opens the previous or next one — available whenever the Research rail is closed")
                )
                #endif
            } header: {
                Text(String(localized: "settings.display.reading.header",
                            defaultValue: "Reading"))
            } footer: {
                if isPhone {
                    Text(String(localized: "settings.display.reading.footer.iphone",
                                defaultValue: "The Research rail opens as a bottom sheet from the toolbar's Research button. It never opens on its own, so it cannot cover a document you only meant to read. Edge-Tap Page Turn moves you between documents while the rail is closed."))
                } else {
                    Text(String(localized: "settings.display.reading.footer",
                                defaultValue: "\"Remember Last\" reopens documents in the mode you used last, Read or Research. Research mode shows the Research rail in a side panel beside the document. Read mode hides the rail so you can just read. The rail toggle inside a document always wins for that document."))
                }
            }

            Section {
                Button {
                    resetDiscoveryTips()
                } label: {
                    Label(String(localized: "settings.display.tips.reset",
                                 defaultValue: "Show Tips Again"),
                          systemImage: "lightbulb")
                }
                .disabled(didResetTips)
                #if os(macOS)
                .buttonStyle(.link)
                #endif
                if didResetTips {
                    Text(String(localized: "settings.display.tips.reset.done",
                                defaultValue: "Tips will appear again as you reach the controls they point at."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(String(localized: "settings.display.tips.header", defaultValue: "Discovery Tips"))
            } footer: {
                Text(String(localized: "settings.display.tips.footer",
                            defaultValue: "Tips point out controls that are easy to miss — the Research button, the page-turn edges, the ways to read a result set. Each retires once you use the control it describes. This brings them all back."))
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .navigationTitle(String(localized: "settings.display.title", defaultValue: "Display"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        // maxWidth only — Session 67 removed `maxHeight: .infinity` here because it stops the
        // NavigationSplitView detail column from bounding the Form's own scroll view.
        .frame(maxWidth: .infinity)
        .scrollIndicators(.visible)
        #endif
    }
}

// MARK: - SearchDefaultsView

/// The Search pane — default scope, default document type, and result-preview length.
///
/// Shared by both platforms since S-5b. The macOS `SettingsSearchPane` it replaces carried a
/// footer that told Mac readers to override these "per-session in the Search sheet" — macOS has
/// a Search *window* with a Filters panel, so that sentence had been wrong on the Mac since the
/// window shipped. One view, one true sentence.
///
/// Version history:
///   1.0 — Session 26: iOS search defaults
///   1.1 — S-5b: shared with macOS; `SettingsSearchPane` deleted
struct SearchDefaultsView: View {
    @AppStorage(SearchDefaults.scopeDocumentsKey) private var scopeDocuments    = true
    @AppStorage(SearchDefaults.scopeNotesKey)     private var scopeNotes        = true
    @AppStorage(SearchDefaults.scopeSummariesKey) private var scopeSummaries    = true
    @AppStorage(SearchDefaults.typeFilterKey)     private var defaultTypeFilter = "all"
    @AppStorage(SearchDefaults.snippetLineCountKey) private var snippetLineCount = SearchDefaults.defaultSnippetLineCount

    /// Whether `scope` is the only search scope still enabled.
    ///
    /// Its toggle is then disabled: with all three off, `SearchService.makeMatchExpressions`
    /// renders no expression for either table and throws `FTS5Error.emptyQuery`, so every search
    /// would fail rather than return an honest empty result. Guarding the last one keeps the
    /// setting in a state the search path can actually execute.
    private func isOnlyEnabledScope(_ scope: Bool) -> Bool {
        scope && [scopeDocuments, scopeNotes, scopeSummaries].filter { $0 }.count == 1
    }

    var body: some View {
        Form {
            Section(header: Text(String(localized: "settings.search.scope.header",
                                        defaultValue: "Default Search Scope")),
                    footer: Text(String(localized: "settings.search.scope.footer",
                                        defaultValue: "These defaults can be overridden per-session in the Search filter panel. At least one scope stays on — searching nothing has no result to show."))) {
                Toggle(String(localized: "settings.search.scope.documents",
                              defaultValue: "Documents"),
                       isOn: $scopeDocuments)
                .disabled(isOnlyEnabledScope(scopeDocuments))
                .accessibilityLabel(
                    String(localized: "settings.search.scope.documents.a11y",
                           defaultValue: "Search FRUS document text by default")
                )
                Text(String(localized: "settings.search.scope.documents.detail",
                            defaultValue: "Search indexed FRUS document text."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle(String(localized: "settings.search.scope.notes",
                              defaultValue: "Research Notes"),
                       isOn: $scopeNotes)
                .disabled(isOnlyEnabledScope(scopeNotes))
                .accessibilityLabel(
                    String(localized: "settings.search.scope.notes.a11y",
                           defaultValue: "Include research notes in search results by default")
                )
                Text(String(localized: "settings.search.scope.notes.detail",
                            defaultValue: "Include your research notes in search results."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle(String(localized: "settings.search.scope.summaries",
                              defaultValue: "AI Summaries"),
                       isOn: $scopeSummaries)
                .disabled(isOnlyEnabledScope(scopeSummaries))
                .accessibilityLabel(
                    String(localized: "settings.search.scope.summaries.a11y",
                           defaultValue: "Include AI summaries in search results by default")
                )
                Text(String(localized: "settings.search.scope.summaries.detail",
                            defaultValue: "Include generated summary text in search results."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(String(localized: "settings.search.typeFilter.header",
                           defaultValue: "Default Document Type")) {
                Picker(String(localized: "settings.search.typeFilter.label",
                              defaultValue: "Default type filter"),
                       selection: $defaultTypeFilter) {
                    Text(String(localized: "settings.search.typeFilter.all",
                                defaultValue: "Documents & Editorial Notes")).tag("all")
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
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        // "Search", not "Search Defaults" — S-0 renamed the row that leads here, and a
        // destination whose title disagrees with the row that opened it reads as a wrong turn.
        .navigationTitle(String(localized: "settings.search.title", defaultValue: "Search"))
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
    /// The global find-related axis tuning, as an `AxisWeights` raw string.
    ///
    /// Device-local by nature and NOT on `SyncedPreferences`: a ranking tuning is edited in the
    /// feature and re-ranks what is on screen, and a stored property on a mirrored `@Model` would
    /// need a Production deploy before shipping (the #488 gate).
    ///
    /// **Absent means "unconfigured", and that is load-bearing** — `ProjectLeadsService`
    /// .effectiveWeights overlays the current defaults onto whatever is stored, so an axis missing
    /// from the string inherits its default rather than an implicit 0. Reset therefore REMOVES this
    /// key rather than writing defaults into it (#1021, #1029).
    static let relatedAxisWeights = "frus.related.weights"

    /// UserDefaults key for the maximum simultaneous volume downloads.
    /// Written by the Downloads settings (both platforms), read at boot by
    /// `FRUSExplorerApp` and applied live via `DownloadManager.setConcurrencyLimit`.
    static let concurrentDownloadLimit = "frus.concurrentDownloadLimit"
    /// How many documents a bulk-summarization run works on at once (#560). Distinct from
    /// ``concurrentDownloadLimit``, which is downloads — reusing that key would make one slider
    /// silently move the other.
    static let summarizationConcurrencyLimit = "frus.summarization.concurrencyLimit"

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

    /// UserDefaults key (Bool, default `true`) controlling whether a volume's semantic-vector
    /// shard is fetched automatically when the volume downloads, and on demand when a semantic
    /// surface first wants it.
    ///
    /// **Device-local by nature, and deliberately NOT on `SyncedPreferences`.** A download policy
    /// is about this device's storage and network — a phone on cellular and a Mac on ethernet want
    /// different answers — which is the same reasoning that keeps
    /// ``allowCellularDownloads`` local. It also keeps this off the CloudKit schema entirely: a
    /// stored property on a mirrored `@Model` would need a Production deploy before shipping
    /// (the #488 gate), and a preference about bytes on one disk has no business there.
    ///
    /// Read by `AppState.fetchSemanticShardIfNeeded(for:reason:)` and applied to the
    /// `.volumeDownloaded` reason ONLY — the ride-along this control names on screen.
    ///
    /// Two paths deliberately ignore it. The manual download, because pressing a button IS the
    /// consent this withholds. And an on-demand fetch from a semantic surface, because reaching one
    /// already required raising an experimental axis off its zero default — a finer and later
    /// consent that a coarser earlier setting should not overrule.
    static let autoDownloadSemanticShards = "frus.semantic.autoDownloadShards"

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

