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
import AppKit

// MARK: - FRUSSettingsView

/// macOS Settings window. Opened via ⌘, (standard macOS Settings scene).
///
/// ## Structure
/// Native macOS sidebar-style settings. The sidebar's sections, rows, labels, and icons all come
/// from the shared `SettingsPane` model (S-1) — see `SettingsPaneModel.swift` for the actual tree,
/// which is the same one iOS renders. This file supplies only the destination view for each pane,
/// and the list above used to be a hand-maintained copy that drifted from what shipped.
///
/// The sidebar is a `List` with section headers so keyboard navigation and VoiceOver work
/// correctly.
///
/// ## Reset
/// Both reset variants (local-only and local + synced) clear
/// `AppState.hasCompletedOnboarding`, which causes `ContentRootView` to immediately
/// replace the main window with `OnboardingView`. Local-only preserves CloudKit
/// data; local + synced deletes SwiftData records as well.
///
/// Version history:
///   1.0 — New UI scaffolding
///   1.1 — Session 101: Log Research Sessions toggle added to SettingsNotesPane
///   1.2 — Session 130:
///          • Window is resizable — NavigationSplitView + min-only frame was already
///            sufficient; every pane (ScrollView-based or Notes split-layout) handles
///            larger windows correctly without modification.
///          • Menu buttons in Projects, Tags, and Summarization panes now show only
///            the ellipsis.circle icon; `.menuIndicatorVisibility(.hidden)` removes
///            the redundant disclosure chevron.
///          • Notes pane: added horizontal padding to note rows for consistency.
///          • Storage pane: index + volume size breakdown added below usage bar;
///            indexing queue card and action buttons moved above the volume table.
///   1.3 — Session 154: Data pane added (Advanced section) — JSON export via
///          NSSavePanel and per-note Markdown export via NSOpenPanel folder picker,
///          both built on ResearchDataExporter.
///   1.4 — Session 2026-07-04 (UI audit A5+A6): `.isSelected` traits on the
///          symbol-swap selection rows (active project, storage candidate rows,
///          compact scope cards); the NARA API-key reveal eye (the audit called
///          it the Zotero eye — the Zotero pane has no reveal control) flips its
///          accessibility label with state
///   1.5 — #258 Phase 2: Volume Scopes pane (SettingsScopesPane, the mac twin of the
///          iOS CustomScopesView row; tags-pane idiom). The shared CustomScopeEditorView
///          gains an explicit macOS sheet body — header / inline filter / bottom-right
///          Cancel–Save — resolving Phase 1's .searchable-in-sheet caution.
///   1.6 — #258 Phase 5: scope rows gain a word-cloud launch button (pendingWordCloud
///          hand-off + direct openWindow, so the launch works with the main window
///          closed; disabled while the scope has no indexed member)
///   1.7 — S-2b: `SettingsStoragePane`, `SettingsAddVolumesPane`, and `ManageStorageSheet`
///          (1,618 lines) leave this file for the merged `MacVolumesStorageHub`; the stale
///          hand-copied sidebar tree in the doc above is replaced by a pointer to the model
struct FRUSSettingsView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var selection: SettingsPane = .volumesStorage

    var body: some View {
        SettingsPane.assertCoverage()
        return NavigationSplitView {
            List(selection: $selection) {
                // Sections come from the shared `SettingsPane` model (S-1), so the sidebar cannot
                // disagree with the iOS root about a pane's name, icon, or group.
                ForEach(SettingsPane.groupedPanes(on: .macOS), id: \.group) { entry in
                    Section(entry.group.label) {
                        ForEach(entry.panes) { pane in
                            Label(pane.label, systemImage: pane.icon)
                                .foregroundStyle(pane == .reset ? .red : .primary)
                                .tag(pane)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 186)
        } detail: {
            Group {
                switch selection {
                case .sync:           SettingsSyncPane()
                case .syncDiagnostics: SettingsSyncDiagnosticsPane()
                case .about:          SettingsAboutPane()
                case .display:        SettingsDisplayPane()
                case .search:         SettingsSearchPane()
                case .projects:       SettingsProjectsPane()
                case .tags:           SettingsTagsPane()
                case .scopes:         SettingsScopesPane()
                case .notes:          SettingsNotesPane()
                case .wordCloud:      WordCloudSettingsView()
                case .volumesStorage: MacVolumesStorageHub()
                case .naraAPI:        SettingsNARAPane()
                case .zotero:         ZoteroIntegrationView()
                case .summarization:  SettingsSummarizationPane()
                case .data:           SettingsDataPane()
                case .reset:          SettingsResetPane()
                // iOS-only panes (see `SettingsPane.platforms`): the sidebar never offers this,
                // so it is unreachable here — but the switch must stay exhaustive over the shared
                // enum, and an empty view is the honest thing to render if one is ever selected
                // programmatically.
                case .researchGuide: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 680, minHeight: 520)
        // #377 Phase 5: land on a specific pane when a menu command asks (e.g. Research ▸ Switch
        // Project ▸ Manage Projects…). `.task` covers a freshly-opened window; `.onChange` covers a
        // Settings window already open behind another. Mirrors MacCollectionManagerView's
        // pendingCollectionSelection idiom. Clearing the field stops a later plain ⌘, re-jumping.
        .task { consumePendingSettingsPane() }
        .onChange(of: appState.pendingSettingsPaneRaw) { _, raw in
            if raw != nil { consumePendingSettingsPane() }
        }
    }

    /// Consumes `AppState.pendingSettingsPaneRaw`, selecting that pane once.
    private func consumePendingSettingsPane() {
        guard let raw = appState.pendingSettingsPaneRaw,
              let pane = SettingsPane(rawValue: raw) else { return }
        selection = pane
        appState.pendingSettingsPaneRaw = nil
    }
}

// `SettingsPane` and `SettingsGroup` now live in the cross-platform `SettingsPaneModel.swift`
// (S-1) so both renderers share one declaration of every pane's label, icon, group, keywords, and
// platform availability. The five hand-maintained sidebar section arrays are gone with it.

// MARK: - Shared Pane Chrome

/// Consistent header for every settings pane.
///
/// Not `private`: `MacVolumesStorageHub` lives in its own file (S-2b) and heads its form with
/// the same title/subtitle pair, so the two must not drift.
struct PaneHeader: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 12)
    }
}

private struct PaneSectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .kerning(0.6)
            .padding(.top, 16)
            .padding(.bottom, 4)
    }
}

// MARK: - About Pane

private struct SettingsAboutPane: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PaneHeader(title: "About")

                HStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("FRUS Explorer")
                            .font(.system(size: 17, weight: .medium))
                        Text("Version \(Bundle.main.shortVersionString)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Text("Build \(Bundle.main.buildNumber)")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.bottom, 20)

                PaneSectionHeader(title: "Acknowledgements")
                Text("FRUS Explorer uses the Foreign Relations of the United States corpus published by the Office of the Historian, U.S. Department of State at history.state.gov. The corpus is in the public domain.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .padding(.bottom, 12)

                Link("Office of the Historian", destination: URL(string: "https://history.state.gov")!)
                    .font(.system(size: 12))
            }
            .padding(24)
        }
    }
}

// MARK: - Display Pane

private struct SettingsDisplayPane: View {
    @AppStorage("frus.display.textSize") private var textSize: TextSizePreference = .medium
    @AppStorage(SettingsKeys.citationStyle) private var citationStyle: CitationStyle = .historyAtState
    @AppStorage(SettingsKeys.defaultDocumentMode) private var defaultDocumentMode: DefaultDocumentMode = .rememberLast
    @AppStorage(ChartSeriesPalette.storageKey) private var chartSeriesCount = ChartSeriesPalette.defaultCount

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PaneHeader(
                    title: "Display",
                    subtitle: "Adjust how documents are presented."
                )

                PaneSectionHeader(title: "Text size")
                Picker("Document text size", selection: $textSize) {
                    ForEach(TextSizePreference.allCases) { size in
                        Text(size.label).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 280)
                .padding(.bottom, 8)

                Text("Adjusts the body text size in the Document view.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)

                PaneSectionHeader(title: "Citations")
                Picker("Citation style", selection: $citationStyle) {
                    ForEach(CitationStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                .padding(.bottom, 8)

                Text("Used for Copy Citation, Share Citation, and the citation popover's default. The popover can still switch styles per-presentation for comparison.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)

                PaneSectionHeader(title: "Reading")
                Picker("Open documents in", selection: $defaultDocumentMode) {
                    ForEach(DefaultDocumentMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                .padding(.bottom, 8)

                Text("\"Remember Last\" reopens documents in whichever mode — Read or Research — you last used. Research mode shows the Research rail alongside the document; Read mode hides it for distraction-free reading. The in-document rail toggle always overrides for the current document.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)

                PaneSectionHeader(title: "Chart colors")
                Stepper(value: $chartSeriesCount, in: ChartSeriesPalette.range) {
                    Text("Distinctly-colored volumes: \(chartSeriesCount)")
                }
                .frame(maxWidth: 280)
                .padding(.bottom, 8)

                Text("How many volumes are shown as distinct colors in the Chronology and Corpus Analytics charts before the rest fold into a single “Other” series. Each chart can override this per view.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(24)
        }
    }
}

// MARK: - Search Pane

/// Optional cross-device settings sync (the device-local master toggle).
private struct SettingsSyncPane: View {
    @AppStorage(SettingsSyncCoordinator.enabledKey) private var syncSettingsEnabled = false
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PaneHeader(
                    title: "iCloud Sync",
                    subtitle: "Optionally share your settings across devices signed in to the same iCloud account."
                )

                settingsPaneToggleRow(
                    label: "Sync settings across devices",
                    detail: "Word-cloud filters & stop lists, citation style, default document mode, and research logging.",
                    isOn: $syncSettingsEnabled
                )
                .disabled(!appState.cloudKitSyncEnabled)
                .onChange(of: syncSettingsEnabled) { _, newValue in
                    appState.settingsSync?.handleEnabledChange(newValue)
                }

                Text(appState.cloudKitSyncEnabled
                     ? "When on, this device shares those settings with your other devices that also have this enabled. Turning it on adopts your existing iCloud settings; leave it off to keep this device's settings separate."
                     : "Settings sync needs iCloud. Sign in to iCloud and enable it for FRUS Explorer to turn this on.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .padding(.top, 10)
            }
            .padding(24)
        }
    }
}

/// The local, redacted CloudKit sync-telemetry log (#188-C.1) — read, copy, export, or clear it
/// to help diagnose iCloud sync problems. Everything shown is on the redaction allow-list: event
/// types, timing, and error codes only.
private struct SettingsSyncDiagnosticsPane: View {
    @State private var text = ""
    @State private var hasEntries = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PaneHeader(
                    title: "Sync Diagnostics",
                    subtitle: "A local, on-device record of iCloud sync events. It contains no personal information and nothing about your documents — only event types, timing, and error codes."
                )

                PaneSectionHeader(title: "Recent sync events")
                ScrollView {
                    Text(text)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 360)
                .padding(.bottom, 12)

                HStack(spacing: 12) {
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }
                    .disabled(!hasEntries)
                    Button("Export…") { exportLog() }
                        .disabled(!hasEntries)
                    Spacer()
                    Button("Clear Log") {
                        Task { await SyncDiagnosticsLog.shared.clear(); await reload() }
                    }
                    .disabled(!hasEntries)
                }
            }
            .padding(24)
        }
        .task { await reload() }
    }

    /// Reloads the log text and entry-presence flag from the actor.
    private func reload() async {
        hasEntries = await !SyncDiagnosticsLog.shared.entries().isEmpty
        text = await SyncDiagnosticsLog.shared.formattedText()
    }

    /// Exports the JSON log via `NSSavePanel` (mirrors `SettingsDataPane.exportJSON`).
    private func exportLog() {
        Task {
            guard let data = await SyncDiagnosticsLog.shared.exportData() else { return }
            await MainActor.run {
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.json]
                panel.nameFieldStringValue = "frus-sync-diagnostics.json"
                panel.begin { response in
                    guard response == .OK, let url = panel.url else { return }
                    try? data.write(to: url, options: .atomic)
                }
            }
        }
    }
}

private struct SettingsSearchPane: View {
    @AppStorage(SearchDefaults.scopeDocumentsKey) private var scopeDocuments  = true
    @AppStorage(SearchDefaults.scopeNotesKey)     private var scopeNotes      = true
    @AppStorage(SearchDefaults.scopeSummariesKey) private var scopeSummaries  = true
    @AppStorage(SearchDefaults.typeFilterKey)     private var defaultTypeFilter = "all"
    @AppStorage(SearchDefaults.snippetLineCountKey) private var snippetLineCount = SearchDefaults.defaultSnippetLineCount

    /// Whether `scope` is the only search scope still enabled — see the iOS twin in
    /// `SearchDefaultsView`. With all three off, `SearchService.makeMatchExpressions` throws
    /// `FTS5Error.emptyQuery`, so every search fails instead of returning an honest empty result.
    private func isOnlyEnabledScope(_ scope: Bool) -> Bool {
        scope && [scopeDocuments, scopeNotes, scopeSummaries].filter { $0 }.count == 1
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PaneHeader(
                    title: "Search",
                    subtitle: "Default scope and filter settings for the Search sheet."
                )

                PaneSectionHeader(title: "Default search scope")
                Text("These toggles control which content types are searched by default. They can be overridden per-session in the Search sheet. At least one scope stays on — searching nothing has no result to show.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .padding(.bottom, 10)

                settingsPaneToggleRow(
                    label: "Documents",
                    detail: "Search indexed FRUS document text.",
                    isOn: $scopeDocuments,
                    isDisabled: isOnlyEnabledScope(scopeDocuments)
                )
                settingsPaneToggleRow(
                    label: "Research notes",
                    detail: "Include your research notes in search results.",
                    isOn: $scopeNotes,
                    isDisabled: isOnlyEnabledScope(scopeNotes)
                )
                settingsPaneToggleRow(
                    label: "AI summaries",
                    detail: "Include generated summary text in search results.",
                    isOn: $scopeSummaries,
                    isDisabled: isOnlyEnabledScope(scopeSummaries)
                )

                PaneSectionHeader(title: "Default document type")
                Picker("Default document type filter", selection: $defaultTypeFilter) {
                    Text("Documents & Editorial Notes").tag("all")
                    Text("Primary documents only").tag("documentsOnly")
                    Text("Editorial notes only").tag("editorialNotesOnly")
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()

                PaneSectionHeader(title: "Result preview")
                Text("How many lines of matched context each search result shows. Individual search screens can override this default.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .padding(.bottom, 10)
                Picker("Snippet length", selection: $snippetLineCount) {
                    ForEach(1...10, id: \.self) { n in
                        Text(SearchDefaults.snippetLinesLabel(n)).tag(n)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 200, alignment: .leading)
            }
            .padding(24)
        }
    }
}

// MARK: - Projects Pane

/// macOS Settings → Research → Projects — the hub for the research trio (S-3b).
///
/// The macOS twin of `ProjectsSettingsView`, in the same order and the same words: context first
/// (Active Project + Project Home), then the list, then the two sibling lists.
///
/// ## What changed in S-3b
/// - The symbol-swap radio that set the active project becomes a **picker**. A column of
///   `checkmark.circle` glyphs beside every row read as selection state, not as a control, and it
///   put "switch context" and "delete this project" a few pixels apart.
/// - The unlabelled `•••` menu becomes the row itself: clicking a row opens `ProjectEditorView`,
///   where rename, merge and delete are visible rows with footers that say what each costs.
/// - "New project" moves out of the pane header into a row at the end of the list it creates into.
/// - Rows carry their tally, so the cost of a delete is visible before it is chosen.
/// - Native `Form(.grouped)` replaces the hand-rolled `ScrollView` + `PaneHeader` + card stack.
///   S-5 was going to convert this pane anyway; doing it here means not building it twice.
private struct SettingsProjectsPane: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    @Query(sort: \Project.name) private var projects: [Project]
    @Query(sort: \UserTag.name) private var tags: [UserTag]
    @Query(sort: \CustomVolumeScope.name) private var scopes: [CustomVolumeScope]

    @State private var showEditor = false
    @State private var editingProject: Project? = nil
    @State private var mergingProject: Project? = nil
    /// How much is filed under each project, fetched once per appearance rather than per row.
    @State private var counts: ResearchItemCounts = .empty

    var body: some View {
        Form {
            Section {
                PaneHeader(
                    title: String(localized: "settings.projects.title", defaultValue: "Projects"),
                    subtitle: String(localized: "settings.projects.pane.subtitle",
                                     defaultValue: "Switch context up top; manage the list below.")
                )

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
                        .labelStyle(.titleAndIcon)
                }

                if let pid = appState.activeProjectId, projects.contains(where: { $0.id == pid }) {
                    Button {
                        // Same call the Browse-toolbar project picker uses; `openWindow(value:)`
                        // on a `WindowGroup(for:)` raises the window itself.
                        openWindow(value: ProjectHomeRequest(projectId: pid))
                    } label: {
                        HStack {
                            Label(String(localized: "settings.projects.home",
                                         defaultValue: "Project Home"),
                                  systemImage: "square.grid.2x2")
                                .labelStyle(.titleAndIcon)
                            Spacer()
                            Image(systemName: "arrow.up.forward.square")
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text(String(localized: "settings.projects.active.footer",
                            defaultValue: "The active project scopes the notes, collections, history, and searches you see. Global Context shows everything."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                if projects.isEmpty {
                    Text(String(localized: "settings.projects.empty.where",
                                defaultValue: "No projects yet. A project keeps one line of research — its notes, collections, history and searches — separate from the rest."))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(projects) { project in
                        Button {
                            editingProject = project
                        } label: {
                            HStack {
                                SettingsNavRow(label: project.name, detail: rowDetail(project))
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                editingProject = project
                            } label: {
                                Label(String(localized: "common.edit", defaultValue: "Edit"),
                                      systemImage: "pencil")
                            }
                            Button {
                                mergingProject = project
                            } label: {
                                Label(String(localized: "project.editor.merge.short",
                                             defaultValue: "Merge into…"),
                                      systemImage: "arrow.triangle.merge")
                            }
                            .disabled(projects.count < 2)
                        }
                    }
                }

                SettingsNewItemRow(label: String(localized: "settings.projects.new",
                                                 defaultValue: "New Project…")) {
                    showEditor = true
                }
            } header: {
                Text(String(localized: "settings.projects.list.header", defaultValue: "Projects"))
            }

            Section {
                Button {
                    appState.pendingSettingsPaneRaw = SettingsPane.tags.rawValue
                } label: {
                    relatedRow(label: String(localized: "settings.pane.tags", defaultValue: "Tags"),
                               systemImage: "tag", detail: tagsDetail)
                }
                .buttonStyle(.plain)
                Button {
                    appState.pendingSettingsPaneRaw = SettingsPane.scopes.rawValue
                } label: {
                    relatedRow(label: String(localized: "settings.pane.scopes",
                                             defaultValue: "Volume Scopes"),
                               systemImage: "square.stack.3d.up", detail: scopesDetail)
                }
                .buttonStyle(.plain)
            } header: {
                Text(String(localized: "settings.projects.related.header", defaultValue: "Related"))
            } footer: {
                Text(String(localized: "settings.projects.related.footer",
                            defaultValue: "Tags and scopes work the same way: tap a row to rename, merge or delete it."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task { counts = ResearchItemCounts.fetch(from: modelContext) }
        .sheet(isPresented: $showEditor) {
            ProjectEditorView(projectToEdit: nil,
                              onSaved: { counts = ResearchItemCounts.fetch(from: modelContext) })
                // ProjectEditorView reads AppState (the second-project nudge signal, #377 Phase 5);
                // re-inject it since a sheet doesn't reliably inherit it.
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
        // #377 Phase 5: the Projects settings pane is on screen when a project is created on
        // macOS, so it hosts the one-time second-project nudge.
        .secondProjectNudge()
    }

    // MARK: - Rows

    @ViewBuilder
    private func relatedRow(label: String, systemImage: String, detail: String) -> some View {
        HStack {
            SettingsNavRow(label: label, systemImage: systemImage, detail: detail)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    /// "12 notes · 3 collections · active", plus the research question when there is one.
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

// MARK: - Volume Scopes Pane (#258 Phase 2)

/// macOS management pane for user-defined volume scopes — the platform twin of the iOS
/// `CustomScopesView` (Settings → Research → Volume Scopes). Mac-native pane idiom
/// (`SettingsTagsPane` pattern); the create/edit sheet is the shared
/// `CustomScopeEditorView`, which carries a mac-specific body (#258 Phase 2 resolved its
/// own Phase-2 caution: explicit chrome instead of `.searchable`-in-sheet).
///
/// Records sync via CloudKit, so scopes created here appear on iOS and vice versa; the
/// shared `SearchFilterView` scope section already consumes them on both platforms.
private struct SettingsScopesPane: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \CustomVolumeScope.name) private var scopes: [CustomVolumeScope]

    /// The scope open in the editor sheet, or `nil` (a fresh uninserted draft for create).
    @State private var editorTarget: CustomVolumeScope?
    /// Whether `editorTarget` is an uninserted draft (create) vs a live record (edit).
    @State private var editorIsDraft = false
    /// The scope pending delete confirmation, or `nil`.
    @State private var scopeToDelete: CustomVolumeScope?

    var body: some View {
        Form {
            Section {
                PaneHeader(
                    title: String(localized: "settings.scopes.title",
                                  defaultValue: "Volume Scopes"),
                    subtitle: String(localized: "settings.scopes.pane.subtitle",
                                     defaultValue: "Named sets of volumes usable as search scopes. Scopes sync to your other devices via iCloud; volumes you haven't downloaded stay in a scope and take effect once indexed.")
                )
            }

            Section {
                if scopes.isEmpty {
                    Text(String(localized: "settings.scopes.empty.detail",
                                defaultValue: "Create a named set of volumes to use as a search scope — for example, every volume covering a crisis, a region, or an administration."))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(scopes) { scope in
                        scopeRow(scope)
                    }
                }

                // S-3b: creation moves out of the pane header into a row at the end of the list it
                // creates into, matching Projects and Tags on both platforms.
                SettingsNewItemRow(label: String(localized: "settings.scopes.new",
                                                 defaultValue: "New Scope…")) {
                    editorIsDraft = true
                    editorTarget = CustomVolumeScope(name: "")
                }
            } header: {
                Text(String(localized: "settings.scopes.title", defaultValue: "Volume Scopes"))
            }
        }
        .formStyle(.grouped)
        .sheet(item: $editorTarget) { target in
            CustomScopeEditorView(scope: target, isDraft: editorIsDraft)
                .environment(appState)
        }
        .confirmationDialog(
            String(localized: "settings.scopes.delete.title", defaultValue: "Delete Scope?"),
            isPresented: Binding(get: { scopeToDelete != nil },
                                 set: { if !$0 { scopeToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button(String(localized: "common.delete", defaultValue: "Delete"),
                   role: .destructive) {
                if let scope = scopeToDelete {
                    modelContext.delete(scope)
                    try? modelContext.save()
                }
                scopeToDelete = nil
            }
            Button(String(localized: "common.cancel", defaultValue: "Cancel"),
                   role: .cancel) { scopeToDelete = nil }
        } message: {
            Text(String(localized: "settings.scopes.delete.message",
                        defaultValue: "Searches already run with this scope are unaffected."))
        }
    }

    /// One scope row: name + live indexed coverage, with Edit / Delete actions.
    private func scopeRow(_ scope: CustomVolumeScope) -> some View {
        let resolution = CustomScopeResolver.indexedResolution(
            memberVolumeIds: scope.volumeIds, indexed: appState.indexedVolumeIds)
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(scope.name.isEmpty
                     ? String(localized: "settings.scopes.unnamed", defaultValue: "Untitled Scope")
                     : scope.name)
                Group {
                    if case .resolved(let ids) = resolution {
                        Text(String(format: String(
                            localized: "settings.scopes.row.indexed %lld %lld",
                            defaultValue: "%lld of %lld volumes indexed"),
                            Int64(ids.count), Int64(scope.volumeIds.count)))
                    } else {
                        Text(String(format: String(
                            localized: "settings.scopes.row.noneIndexed %lld",
                            defaultValue: "%lld volumes — none indexed yet"),
                            Int64(scope.volumeIds.count)))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            // #258 Phase 5: word-cloud launch. Opens the window DIRECTLY rather than
            // relying on MainWindowView's pendingWordCloud observer (the #333 review's
            // parked-hand-off note: with the main window closed, the observer never
            // fires and the value parks). The window consumes `pendingWordCloud` on
            // appear, or retargets via its own onChange when already open. Disabled
            // when nothing is indexed: the cloud reads indexed text, so a zero-indexed
            // scope could only ever render an empty cloud.
            Button {
                appState.openWordCloud(.customScope(id: scope.id), from: nil)   // #338: macOS singleton window
                // Settings has no document-host provenance — clear the word cloud's binding so any
                // document open it spawns resolves via the D3 recency fallback, not a stale host.
                appState.bindTool(.wordCloud, to: nil)
                openWindow(id: "frus.wordcloud")
                // An already-open cloud window retargets via its onChange, but openWindow(id:)
                // does not raise it — front it explicitly, like every other direct open (#334).
                bringMacWindowToFront(id: "frus.wordcloud")
            } label: {
                Image(systemName: WordCloudGlyph.symbol)
            }
            .buttonStyle(.borderless)
            .disabled(resolution == .noIndexedMembers)
            .help(String(localized: "settings.scopes.row.wordCloud.help",
                         defaultValue: "Open a word cloud of this scope's indexed volumes"))
            .accessibilityLabel(String(format: String(
                localized: "settings.scopes.row.wordCloud.a11y %@",
                defaultValue: "Word cloud of %@"), scope.name))
            Button(String(localized: "common.edit", defaultValue: "Edit")) {
                editorIsDraft = false
                editorTarget = scope
            }
            .buttonStyle(.borderless)
            Button(role: .destructive) {
                scopeToDelete = scope
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(String(format: String(
                localized: "settings.scopes.delete.a11y %@",
                defaultValue: "Delete %@"), scope.name))
        }
    }
}

// MARK: - Tags Pane

/// macOS Settings → Research → Tags — the same list grammar as Projects (S-3b).
///
/// ## What changed in S-3b
/// - The unlabelled `•••` menu becomes the row: clicking a row opens the shared `TagEditorView`,
///   where rename, merge and delete are visible rows with footers that state what each costs. The
///   menu survives as a right-click context menu for people who reach for one.
/// - The "Create tag" text field + Add button at the top of the pane becomes a "New Tag…" row at
///   the end of the list it creates into, matching iOS and Projects.
/// - Rows carry their attachment tally from `ResearchItemCounts` (S-3a) instead of the old
///   per-row full-table fetch.
/// - Native `Form(.grouped)` replaces the hand-rolled `ScrollView` + card stack (S-5's list drops
///   this pane with it).
/// - `TagRenameSheet` retires: a rename-only sheet is exactly the single-purpose affordance the
///   editor replaces.
private struct SettingsTagsPane: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserTag.name) private var tags: [UserTag]

    @State private var editingTag: UserTag? = nil
    @State private var mergingTag: UserTag? = nil
    /// A freshly created tag, opened straight into the editor so it can be named.
    @State private var pendingNewTag: UserTag? = nil
    /// How much is attached to each tag, fetched once per appearance rather than per row.
    @State private var counts: ResearchItemCounts = .empty

    var body: some View {
        Form {
            Section {
                PaneHeader(
                    title: String(localized: "settings.pane.tags", defaultValue: "Tags"),
                    subtitle: String(localized: "settings.tags.pane.subtitle",
                                     defaultValue: "Tags are global labels you apply to research notes and documents. They are not scoped to a project.")
                )
            }

            Section {
                if tags.isEmpty {
                    Text(String(localized: "settings.tags.empty.where",
                                defaultValue: "No tags yet. Tags are the labels you apply to research notes and documents as you read — create one here, or from any note."))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tags) { tag in
                        Button {
                            editingTag = tag
                        } label: {
                            HStack {
                                SettingsNavRow(label: tag.name, detail: counts.tag(tag.id).summary)
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                editingTag = tag
                            } label: {
                                Label(String(localized: "common.edit", defaultValue: "Edit"),
                                      systemImage: "pencil")
                            }
                            Button {
                                mergingTag = tag
                            } label: {
                                Label(String(localized: "tag.editor.merge.short",
                                             defaultValue: "Merge into…"),
                                      systemImage: "arrow.triangle.merge")
                            }
                            .disabled(tags.count < 2)
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
            }
        }
        .formStyle(.grouped)
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

// MARK: - Notes Pane

private struct SettingsNotesPane: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ResearchNote.lastModified, order: .reverse) private var allNotes: [ResearchNote]
    @Query private var projects: [Project]
    @Query(sort: \UserTag.name) private var tags: [UserTag]

    @AppStorage("researchSessionLoggingEnabled") private var loggingEnabled = true

    @State private var filterProjectId: UUID? = nil
    @State private var filterTagId: UUID? = nil
    @State private var noteToEdit: ResearchNote? = nil
    @State private var noteToDelete: ResearchNote? = nil
    @State private var showDeleteConfirmation = false

    private var filteredNotes: [ResearchNote] {
        allNotes.filter { note in
            let matchesProject: Bool = {
                guard let pid = filterProjectId else { return true }
                return note.projectIds.contains(pid)
            }()
            let matchesTag: Bool = {
                guard let tid = filterTagId else { return true }
                return note.userTagIds.contains(tid)
            }()
            return matchesProject && matchesTag
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header + filters
            VStack(alignment: .leading, spacing: 0) {
                PaneHeader(
                    title: "Notes",
                    subtitle: "Manage your research notes across all documents."
                )

                Toggle("Log Research Sessions", isOn: $loggingEnabled)
                    .padding(.bottom, 8)

                HStack(spacing: 12) {
                    // Project filter
                    Picker("Project", selection: $filterProjectId) {
                        Text("All projects").tag(UUID?.none)
                        Text("Untagged").tag(UUID?.some(UUID(uuidString: "00000000-0000-0000-0000-000000000000")!))
                        ForEach(projects) { project in
                            Text(project.name).tag(UUID?.some(project.id))
                        }
                    }
                    .frame(maxWidth: 180)

                    // Tag filter
                    Picker("Tag", selection: $filterTagId) {
                        Text("All tags").tag(UUID?.none)
                        ForEach(tags) { tag in
                            Text(tag.name).tag(UUID?.some(tag.id))
                        }
                    }
                    .frame(maxWidth: 180)

                    Spacer()

                    Text("\(filteredNotes.count) note\(filteredNotes.count == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .padding(.bottom, 12)
            }
            .padding(24)
            .padding(.bottom, 0)

            Divider()

            // Notes list
            if filteredNotes.isEmpty {
                ContentUnavailableView(
                    "No Notes",
                    systemImage: "note.text",
                    description: Text(filterProjectId != nil || filterTagId != nil
                        ? "No notes match the selected filters."
                        : "Research notes you add from the document view will appear here.")
                )
            } else {
                List {
                    ForEach(filteredNotes) { note in
                        noteRow(note)
                            .contentShape(Rectangle())
                            .onTapGesture { noteToEdit = note }
                    }
                }
                .listStyle(.plain)
            }
        }
        .sheet(item: $noteToEdit) { note in
            ResearchNoteEditorView(
                documentId: note.documentId,
                volumeId: note.volumeId,
                activeProjectId: nil,
                noteToEdit: note
            )
        }
        .confirmationDialog(
            "Delete Note?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let note = noteToDelete { modelContext.delete(note) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This note will be permanently deleted.")
        }
    }

    private func noteRow(_ note: ResearchNote) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if note.bodyText.isEmpty {
                Text("Empty note")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                Text(note.bodyText)
                    .font(.system(size: 13))
                    .lineLimit(2)
            }
            HStack(spacing: 6) {
                Text("\(note.volumeId) / \(note.documentId)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                ForEach(projectNamesFor(note), id: \.self) { name in
                    Text(name)
                        .font(.system(size: 10))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
                ForEach(tagNamesFor(note), id: \.self) { name in
                    Text("◆ \(name)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let date = note.lastModified {
                    Text(date, style: .date)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contextMenu {
            Button(role: .destructive) {
                noteToDelete = note
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func projectNamesFor(_ note: ResearchNote) -> [String] {
        note.projectIds.compactMap { pid in projects.first { $0.id == pid }?.name }
    }

    private func tagNamesFor(_ note: ResearchNote) -> [String] {
        note.userTagIds.compactMap { tid in tags.first { $0.id == tid }?.name }
    }
}

// MARK: - NARA API Pane

private struct SettingsNARAPane: View {
    @State private var apiKey: String = ""
    @State private var isRevealed: Bool = false
    @State private var isSaved: Bool = false
    @State private var callCount: Int = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PaneHeader(
                    title: "NARA API",
                    subtitle: "Store your National Archives catalog API key to enable the Source Explorer."
                )

                PaneSectionHeader(title: "API key")
                Text("The NARA API key is stored securely in iCloud Keychain and synced across your devices. The Source Explorer toolbar button is only shown when a key is configured.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .padding(.bottom, 12)

                HStack(spacing: 8) {
                    Group {
                        if isRevealed {
                            TextField("Paste your NARA API key", text: $apiKey)
                        } else {
                            SecureField("NARA API key", text: $apiKey)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)

                    Button {
                        isRevealed.toggle()
                    } label: {
                        Image(systemName: isRevealed ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    // A6: the label flips with state so VoiceOver announces the
                    // action the button will actually perform.
                    .accessibilityLabel(isRevealed
                        ? String(localized: "settings.apiKey.conceal",
                                 defaultValue: "Conceal API key")
                        : String(localized: "settings.apiKey.reveal",
                                 defaultValue: "Reveal API key"))

                    Button("Save") {
                        saveKey()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if isSaved {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                    }
                }
                .padding(.bottom, 8)

                if !apiKey.isEmpty {
                    Button("Remove key from keychain") {
                        removeKey()
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .buttonStyle(.plain)
                }

                PaneSectionHeader(title: "Usage (last 30 days)")
                HStack {
                    Text("\(callCount) API call\(callCount == 1 ? "" : "s")")
                        .font(.system(size: 13))
                    Spacer()
                    Text("Limit not enforced by FRUS Explorer")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .padding(10)
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 7))

                Link("Get a NARA API key", destination: URL(string: "https://www.archives.gov/research/catalog/help/api")!)
                    .font(.system(size: 12))
                    .padding(.top, 12)
            }
            .padding(24)
        }
        .onAppear { loadKey() }
    }

    private func loadKey() {
        apiKey = NARAAPIKeyStore.shared.retrieveKey() ?? ""
        callCount = NARAAPIKeyStore.shared.callCountLast30Days
    }

    private func saveKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        NARAAPIKeyStore.shared.storeKey(trimmed)
        withAnimation { isSaved = true }
        Task { try? await Task.sleep(for: .seconds(2)); isSaved = false }
    }

    private func removeKey() {
        NARAAPIKeyStore.shared.deleteKey()
        apiKey = ""
    }
}

// MARK: - Summarization Pane

/// macOS Settings → Research → Summarization — the twin of `SummarizationPromptsSettingsView` (S-3d).
///
/// Availability first, receipt last, prompts in between; the batch-run form moves behind a "New
/// Batch Run…" door. Native `Form(.grouped)` replaces the hand-rolled `ScrollView` + card stack and
/// its fixed 11–13pt type, so S-5's conversion list loses this pane too.
private struct SettingsSummarizationPane: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SummarizationPrompt.createdAt) private var allPrompts: [SummarizationPrompt]

    @State private var promptToEdit: SummarizationPrompt? = nil
    @State private var showNewPromptSheet: Bool = false
    @State private var newPromptInitialTemplate: PromptTemplate? = nil
    @State private var showRunSheet = false
    /// Per-prompt summary counts, tallied once per appearance rather than per row.
    @State private var tally: PromptSummaryTally = .empty

    private var standardPrompts: [SummarizationPrompt] { allPrompts.filter { $0.isStandard } }
    private var userPrompts: [SummarizationPrompt] { allPrompts.filter { !$0.isStandard } }

    var body: some View {
        Form {
            Section {
                PaneHeader(
                    title: String(localized: "settings.pane.summarization",
                                  defaultValue: "Summarization"),
                    subtitle: String(localized: "settings.summarization.pane.subtitle",
                                     defaultValue: "Prompts, summaries and batch runs.")
                )

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

            if !standardPrompts.isEmpty {
                Section {
                    ForEach(standardPrompts) { prompt in
                        HStack {
                            SettingsNavRow(label: prompt.name,
                                           detail: tally.rowSummary(for: prompt.id))
                            Spacer(minLength: 8)
                            Button(String(localized: "settings.summarization.useAsTemplate",
                                          defaultValue: "Use as Template")) {
                                newPromptInitialTemplate = templateFrom(prompt)
                                showNewPromptSheet = true
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(
                                String(localized: "settings.summarization.useAsTemplate.a11y",
                                       defaultValue: "Use \(prompt.name) as a template for a new prompt"))
                        }
                    }
                } header: {
                    Text(String(localized: "settings.summarization.standard.header",
                                defaultValue: "Standard Prompts"))
                } footer: {
                    Text(String(localized: "settings.summarization.standard.footer",
                                defaultValue: "The prompts the app ships with. They can't be edited — start from one with Use as Template."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                if userPrompts.isEmpty {
                    Text(String(localized: "settings.summarization.user.empty.where",
                                defaultValue: "No prompts of your own yet. Prompts you create appear here and sync to your other devices via iCloud."))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(userPrompts) { prompt in
                        Button {
                            promptToEdit = prompt
                        } label: {
                            HStack {
                                SettingsNavRow(label: prompt.name,
                                               detail: tally.rowSummary(for: prompt.id))
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        // The ••• menu was the only way to reach these and carried no label of its
                        // own; the row now opens the editor and the menu survives as a right-click.
                        .accessibilityLabel(
                            String(localized: "settings.summarization.prompt.a11y2",
                                   defaultValue: "\(prompt.name), \(tally.rowSummary(for: prompt.id))"))
                        .contextMenu {
                            Button { promptToEdit = prompt } label: {
                                Label(String(localized: "common.edit", defaultValue: "Edit"),
                                      systemImage: "pencil")
                            }
                            Button {
                                newPromptInitialTemplate = templateFrom(prompt)
                                showNewPromptSheet = true
                            } label: {
                                Label(String(localized: "settings.summarization.duplicate",
                                             defaultValue: "Duplicate"), systemImage: "doc.on.doc")
                            }
                            Divider()
                            Button(role: .destructive) {
                                modelContext.delete(prompt)
                                refreshTally()
                            } label: {
                                Label(String(localized: "common.delete", defaultValue: "Delete"),
                                      systemImage: "trash")
                            }
                        }
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

            generateSection
        }
        .formStyle(.grouped)
        .task { refreshTally() }
        .sheet(item: $promptToEdit, onDismiss: refreshTally) { prompt in
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
                                   defaultValue: "Scope, prompt and progress."))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            SettingsNavRow(
                label: String(localized: "settings.summarization.generated",
                              defaultValue: "Generated so far"),
                value: "\(tally.documentSummaries)")

            SettingsStatusRow(
                label: String(localized: "settings.summarization.lastRun",
                              defaultValue: "Last run"),
                detail: BatchRunReceipt.text(for: runState),
                state: BatchRunReceipt.isFailure(runState)
                    ? .error
                    : (BatchRunReceipt.isCancelled(runState) ? .warning : .ok))
        } header: {
            Text(String(localized: "settings.summarization.generate.header",
                        defaultValue: "Generate"))
        } footer: {
            Text(headnoteFooter)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// The count's caveat — see the iOS twin for why headnote drafts are excluded.
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

    private func refreshTally() {
        tally = SummarizationPaneTally.fetch(from: modelContext)
    }

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

// MARK: - Data Pane

/// Settings → Data — research data export.
///
/// macOS counterpart to iOS `ResearchDataExportView`. Builds the same
/// `ResearchDataEnvelope` via `ResearchDataExporter` but saves to disk through
/// `NSSavePanel` (JSON) and `NSOpenPanel` (a destination folder for the
/// per-note Markdown export) rather than a share sheet.
///
/// Version history:
///   1.0 — Session 154: initial implementation
private struct SettingsDataPane: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query private var notes: [ResearchNote]
    @Query private var tags: [UserTag]
    @Query private var tagAssignments: [DocumentTagAssignment]
    @Query private var highlights: [DocumentHighlight]
    @Query private var collections: [Collection]
    @Query private var prompts: [SummarizationPrompt]
    @Query private var projects: [Project]
    @Query private var summaries: [GeneratedSummary]

    @State private var includeGeneratedSummaries = false
    @State private var isExportingMarkdown = false
    @State private var statusMessage: String?

    private var userPromptCount: Int {
        prompts.filter { !$0.isStandard }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PaneHeader(
                    title: "Data",
                    subtitle: "Export your research notes, tags, highlights, collections, prompts, and projects."
                )

                PaneSectionHeader(title: "Contents")
                VStack(alignment: .leading, spacing: 4) {
                    contentsRow("Research Notes", notes.count)
                    contentsRow("Tags & Assignments", tags.count + tagAssignments.count)
                    contentsRow("Highlights", highlights.count)
                    contentsRow("Collections", collections.count)
                    contentsRow("Custom Prompts", userPromptCount)
                    contentsRow("Projects", projects.count)
                }
                .padding(.bottom, 12)

                PaneSectionHeader(title: "Export")

                Toggle("Include AI-Generated Summaries", isOn: $includeGeneratedSummaries)
                Text("Adds all \(summaries.count) generated summaries to the JSON export. Off by default since AI output can be large.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)

                HStack(spacing: 8) {
                    Button("Export as JSON…") { exportJSON() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                    Button("Export Notes as Markdown…") { exportMarkdown() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isExportingMarkdown || notes.isEmpty)
                }

                if isExportingMarkdown {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.6, anchor: .center)
                        Text("Writing Markdown files…")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                } else if let statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }

                if BrokenRefsIndexStore.shared != nil {
                    PaneSectionHeader(title: "Broken Cross-References Report")
                        .padding(.top, 16)
                    Text("The corpus-wide list of cross-references in the printed FRUS volumes that point to a document, page, or volume not present in the corpus. The CSV lists distinct broken targets; the fuller per-occurrence spreadsheet with source line numbers is generated offline.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)
                    HStack(spacing: 8) {
                        Button("Export CSV…") { exportBrokenRefsCSV() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        Button("Export JSON…") { exportBrokenRefsJSON() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }
            .padding(24)
        }
    }

    private func contentsRow(_ label: String, _ count: Int) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
            Spacer()
            Text("\(count)")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    /// Builds the JSON envelope and presents `NSSavePanel` to write it to disk.
    private func exportJSON() {
        do {
            let envelope = try ResearchDataExporter.makeEnvelope(
                modelContext: modelContext,
                includeGeneratedSummaries: includeGeneratedSummaries,
                activeProjectId: appState.activeProjectId
            )
            let data = try ResearchDataExporter.exportJSONData(envelope)

            let panel = NSSavePanel()
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "frus-research-export.json"
            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }
                do {
                    try data.write(to: url, options: .atomic)
                    statusMessage = "Saved to \(url.lastPathComponent)."
                } catch {
                    statusMessage = "Couldn't save the export: \(error.localizedDescription)"
                }
            }
        } catch {
            statusMessage = "Couldn't prepare the export: \(error.localizedDescription)"
        }
    }

    /// Writes the bundled broken cross-references index as CSV via `NSSavePanel` (#240B).
    private func exportBrokenRefsCSV() {
        guard let index = BrokenRefsIndexStore.shared else { return }
        let data = Data(BrokenRefsReportExporter.csv(from: index).utf8)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "frus-broken-cross-references.csv"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
                statusMessage = "Saved to \(url.lastPathComponent)."
            } catch {
                statusMessage = "Couldn't save the report: \(error.localizedDescription)"
            }
        }
    }

    /// Writes the bundled broken cross-references index as JSON via `NSSavePanel` (#240B).
    private func exportBrokenRefsJSON() {
        do {
            let data = try BrokenRefsReportExporter.jsonData()
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "frus-broken-cross-references.json"
            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }
                do {
                    try data.write(to: url, options: .atomic)
                    statusMessage = "Saved to \(url.lastPathComponent)."
                } catch {
                    statusMessage = "Couldn't save the report: \(error.localizedDescription)"
                }
            }
        } catch {
            statusMessage = "Couldn't prepare the report: \(error.localizedDescription)"
        }
    }

    /// Prompts for a destination folder via `NSOpenPanel`, then writes one
    /// Markdown file per research note into it.
    private func exportMarkdown() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Choose a folder to save a Markdown file for each research note."
        guard panel.runModal() == .OK, let directory = panel.url else { return }

        isExportingMarkdown = true
        Task {
            let exports = await ResearchDataExporter.markdownExports(notes: notes, tags: tags, appState: appState)
            var written = 0
            for export in exports {
                let url = directory.appendingPathComponent(export.filename)
                if (try? export.content.write(to: url, atomically: true, encoding: .utf8)) != nil {
                    written += 1
                }
            }
            statusMessage = "Saved \(written) note\(written == 1 ? "" : "s") to \(directory.lastPathComponent)."
            isExportingMarkdown = false
        }
    }
}

// MARK: - Reset Pane

private struct SettingsResetPane: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var showLocalResetConfirmation  = false
    @State private var showFullResetConfirmation   = false
    @State private var showSyncResetConfirmation   = false
    @State private var isResetting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PaneHeader(
                    title: "Reset",
                    subtitle: "Reset FRUS Explorer to its initial state."
                )

                // iCloud sync reset (least destructive — recommended when sync is broken)
                resetCard(
                    title: "Reset iCloud sync",
                    description: "Clears the local iCloud sync state and re-downloads your notes, collections, tags, and projects from iCloud on the next launch. Use this when sync appears stuck or is consistently reporting errors. Local data is not deleted.",
                    buttonLabel: "Reset iCloud sync…",
                    buttonRole: .destructive,
                    action: { showSyncResetConfirmation = true }
                )
                .padding(.bottom, 12)

                // Local only
                resetCard(
                    title: "Reset local data",
                    description: "Deletes all downloaded volume files and the search index from this Mac. Your notes, collections, tags, and projects remain in iCloud and will be restored on next launch.",
                    buttonLabel: "Reset local data…",
                    buttonRole: .destructive,
                    action: { showLocalResetConfirmation = true }
                )
                .padding(.bottom, 12)

                // Full reset
                resetCard(
                    title: "Reset all data",
                    description: "Deletes downloaded volume files, the search index, and all user data — notes, collections, tags, and projects — from both this Mac and iCloud. This cannot be undone.",
                    buttonLabel: "Reset all data…",
                    buttonRole: .destructive,
                    action: { showFullResetConfirmation = true }
                )
            }
            .padding(24)
        }
        .overlay {
            if isResetting {
                ZStack {
                    Color.black.opacity(0.25)
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Resetting…")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .confirmationDialog(
            "Reset local data?",
            isPresented: $showLocalResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset local data", role: .destructive) {
                Task { await performReset(includeCloudKit: false) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Volume files and the search index will be deleted from this Mac. Your notes and collections in iCloud are not affected.")
        }
        .confirmationDialog(
            "Reset all data?",
            isPresented: $showFullResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset all data", role: .destructive) {
                Task { await performReset(includeCloudKit: true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All data — including notes, collections, tags, and projects — will be permanently deleted from this Mac and iCloud. This cannot be undone.")
        }
        .confirmationDialog(
            "Reset iCloud sync?",
            isPresented: $showSyncResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset iCloud sync", role: .destructive) {
                Task { await performSyncReset() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The local iCloud sync state will be cleared. Your data in iCloud is not deleted. The app will re-download your notes, collections, and tags from iCloud when it next launches.")
        }
    }

    // MARK: iCloud Sync Reset

    /// Clears the local SwiftData persistent store so the app re-downloads from CloudKit
    /// on the next launch. iCloud data is NOT deleted.
    ///
    /// This is the recommended first step when sync is consistently failing.
    /// After this action the app automatically returns to onboarding so the
    /// container is freshly initialised against the current CloudKit schema.
    @MainActor
    private func performSyncReset() async {
        isResetting = true

        // 1. Remove the local SQLite store used by SwiftData.
        //    SwiftData stores the container at Application Support/[BundleID]/ on iOS
        //    and Application Support/FRUSExplorer/ on macOS for local configs.
        //    We delete all SQLite files in the standard SwiftData store locations
        //    so the next ModelContainer init re-downloads from CloudKit.
        let fm = FileManager.default
        let appSupportURLs = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        for base in appSupportURLs {
            // SwiftData default store names vary; delete any .sqlite files in the app's
            // Application Support directory that aren't our FTS5 index.
            let appDir = base.appendingPathComponent("FRUSExplorer", isDirectory: true)
            if let contents = try? fm.contentsOfDirectory(at: appDir,
                                                            includingPropertiesForKeys: nil) {
                for url in contents where url.pathExtension == "sqlite"
                                           && !url.lastPathComponent.hasPrefix("frus") {
                    try? fm.removeItem(at: url)
                    print("[Settings] Removed SwiftData store: \(url.lastPathComponent)")
                }
            }
            // Also check the standard SwiftData bundle-id directory
            if let bundleId = Bundle.main.bundleIdentifier {
                let bundleDir = base.appendingPathComponent(bundleId, isDirectory: true)
                if let contents = try? fm.contentsOfDirectory(at: bundleDir,
                                                               includingPropertiesForKeys: nil) {
                    for url in contents where url.pathExtension == "sqlite" {
                        try? fm.removeItem(at: url)
                        print("[Settings] Removed SwiftData store: \(url.lastPathComponent)")
                    }
                }
            }
        }

        // 2. Clear onboarding flag so the app presents a fresh launch on restart.
        appState.hasCompletedOnboarding = false
        isResetting = false

        #if os(macOS)
        // Close the Settings window; the main window will show onboarding.
        NSApplication.shared.keyWindow?.close()
        #endif
    }

    // MARK: Reset Card

    private func resetCard(
        title: String,
        description: String,
        buttonLabel: String,
        buttonRole: ButtonRole,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
            Text(description)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Button(buttonLabel, role: buttonRole, action: action)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.red.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: Reset Actions

    @MainActor
    private func performReset(includeCloudKit: Bool) async {
        // Capture the Settings window NOW — before any `await` suspends this task.
        // After an await the key window may have changed, making post-hoc title
        // matching unreliable.
        let settingsWindow = NSApplication.shared.keyWindow

        isResetting = true

        // 1-2. Delete downloaded volume XML and clear the search index; return to onboarding.
        await ResetService.resetLocalData(appState: appState)

        // 3. If full reset, also delete all SwiftData records
        if includeCloudKit {
            deleteAllUserData()
        }

        isResetting = false

        // 4. Close auxiliary windows (Search, Corpus Browser, etc.) — they'd be confusing
        //    during onboarding and might obscure the ContentView window which has already
        //    switched to OnboardingView. NSApplication.mainWindow is unreliable here: it
        //    returns whichever window last had focus (often an auxiliary window), not the
        //    ContentView/WindowGroup window.
        let auxiliaryTitles: Set<String> = [
            "Search", "Corpus Browser", "Cross-Reference Graph",
            "Source Explorer", "Collections", "About FRUS Explorer"
        ]
        for window in NSApplication.shared.windows where auxiliaryTitles.contains(window.title) {
            window.close()
        }
        // Close Settings last; macOS automatically makes the remaining ContentView window key.
        settingsWindow?.close()

        #if DEBUG
        print("[Settings] Reset complete. includeCloudKit=\(includeCloudKit)")
        #endif
    }

    private func deleteAllUserData() {
        // Dependent records are listed BEFORE the records they reference. This loop is not
        // transactional, so if a reset is interrupted (an individual delete failing, OS
        // termination) a leftover child is harmless but a leftover reference to an already-deleted
        // parent is an orphan. In particular `DocumentTagAssignment` must precede `UserTag` —
        // otherwise an interrupted reset leaves dangling assignments that the boot-time
        // `OrphanedTagRepair` would resurrect as "Recovered Tag" placeholders for tags the user
        // explicitly asked to delete (#406). Mirrors iOS `SettingsView.performReset`.
        let types: [any PersistentModel.Type] = [
            // Children / references first.
            DocumentTagAssignment.self,   // #406: previously omitted → orphaned assignments syncing
            DocumentHighlight.self,       // #406: previously omitted → stranded highlights syncing
            // `Collection.documentEntries` has deleteRule `.nullify`, not cascade, so entries must be
            // deleted explicitly and before their `Collection` — otherwise a full reset leaves
            // orphaned `CollectionEntry` rows (collection=nil) that CloudKit keeps syncing.
            CollectionEntry.self,
            ResearchNote.self,
            // Parents next.
            UserTag.self,
            Collection.self,       // project's SwiftData model is Collection, not DocumentCollection
            GeneratedSummary.self,
            ReadingHistoryEntry.self,
            SummarizationPrompt.self,
            Project.self,
        ]
        for type in types {
            try? modelContext.delete(model: type)
        }
    }
}

// MARK: - Shared Helpers

/// Toggle row used across multiple settings panes.
/// Named `settingsPaneToggleRow` to avoid collision with `settingsToggleRow` in SettingsView.swift.
@ViewBuilder
private func settingsPaneToggleRow(label: String,
                                   detail: String,
                                   isOn: Binding<Bool>,
                                   isDisabled: Bool = false) -> some View {
    HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 13))
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        Spacer()
        Toggle("", isOn: isOn)
            .labelsHidden()
            .disabled(isDisabled)
    }
    .padding(10)
    .background(Color.secondary.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 7))
    .padding(.bottom, 6)
}

// MARK: - Bundle Helpers

private extension Bundle {
    var shortVersionString: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}

#endif // os(macOS)
