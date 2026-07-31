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
///   1.8 — S-5b: the last four hand-rolled `ScrollView`/`PaneHeader` panes go. Display,
///          Search and Sync are deleted outright in favour of the cross-platform
///          `DisplaySettingsView` / `SearchDefaultsView` / `SyncSettingsSection` — there was
///          never a macOS-specific behaviour in them, only drifted copy. Notes is rewritten
///          as a `Form` over a one-shot `NotesPaneSnapshot` (it held three live `@Query`s over
///          every note, the documented CPU-peg shape) with the full list behind one door.
///          `PaneSectionHeader`, `settingsPaneToggleRow`, and a dead `Bundle` extension go
///          with them.
///   1.9 — The Notes pane leaves this file for the cross-platform `NotesSettingsView`: it holds
///          the Log Research Sessions switch, which iOS lost in S-1, and giving iOS the pane
///          puts the switch back where the user already knows to find it.
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
                            // No row is tinted destructive any more: S-4b moved Erase Everything
                            // behind Data & Recovery, so the sidebar has no destructive entry.
                            Label(pane.label, systemImage: pane.icon)
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
                // Display, Search and Sync render the cross-platform views (S-5b). The macOS
                // twins they replaced held no macOS-specific behaviour — only copy that had
                // drifted from the iOS original.
                case .sync:           SyncSettingsView()
                case .about:          AboutView()
                case .display:        DisplaySettingsView()
                case .search:         SearchDefaultsView()
                case .projects:       SettingsProjectsPane()
                case .tags:           SettingsTagsPane()
                case .scopes:         SettingsScopesPane()
                case .workingCorpora: WorkingCorporaView()
                case .notes:          NotesSettingsView()
                case .researchSessions: ResearchSessionsView()
                case .wordCloud:      WordCloudSettingsView()
                case .volumesStorage: MacVolumesStorageHub()
                case .connections:    ConnectionsView()
                case .dataRecovery:   DataRecoveryView()
                case .summarization:  SettingsSummarizationPane()
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
/// - Native `Form(.grouped)` replaces the hand-rolled `ScrollView` + card stack.
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
                Text(String(localized: "settings.projects.list.header", defaultValue: "All Projects"))
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
                            defaultValue: "Open Tags to rename, merge or delete a tag. Open Volume Scopes to edit or delete a scope — scopes cannot be merged."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(String(localized: "settings.projects.title", defaultValue: "Projects"))
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
            } footer: {
                Text(String(localized: "settings.scopes.pane.subtitle",
                            defaultValue: "Named sets of volumes usable as search scopes. Scopes sync to your other devices via iCloud; volumes you haven't downloaded stay in a scope and take effect once indexed."))
            }
        }
        .formStyle(.grouped)
        .navigationTitle(String(localized: "settings.scopes.title", defaultValue: "Volume Scopes"))
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
            } footer: {
                Text(String(localized: "settings.tags.pane.subtitle",
                            defaultValue: "Tags are global labels you apply to research notes and documents. They are not scoped to a project."))
            }
        }
        .formStyle(.grouped)
        .navigationTitle(String(localized: "settings.pane.tags", defaultValue: "Tags"))
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
        .navigationTitle(String(localized: "settings.pane.summarization",
                                defaultValue: "Summarization"))
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
        // The "set per run" promise is an iOS one: the background-continuation choice is part of
        // the iOS run sheet and macOS has no equivalent control, so the Mac footer says what the
        // Mac actually does.
        let base = String(localized: "settings.summarization.generate.footer.mac",
                          defaultValue: "Runs continue while the app is open.")
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

#endif // os(macOS)
