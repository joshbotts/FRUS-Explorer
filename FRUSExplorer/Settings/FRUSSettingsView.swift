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
/// Native macOS sidebar-style settings with logical groupings:
///
///   General
///     About
///     Display
///     Search
///   Research
///     Projects
///     Tags
///     Notes
///   Corpus
///     Storage
///     Downloads
///   Advanced
///     NARA API
///     Summarization
///   Reset
///
/// Each pane is a dedicated view. The sidebar is a `List` with section headers
/// so keyboard navigation and VoiceOver work correctly.
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
struct FRUSSettingsView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var selection: SettingsPane = .display

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("General") {
                    ForEach(SettingsPane.general) { pane in
                        Label(pane.label, systemImage: pane.icon)
                            .tag(pane)
                    }
                }
                Section("Research") {
                    ForEach(SettingsPane.research) { pane in
                        Label(pane.label, systemImage: pane.icon)
                            .tag(pane)
                    }
                }
                Section("Corpus") {
                    ForEach(SettingsPane.corpus) { pane in
                        Label(pane.label, systemImage: pane.icon)
                            .tag(pane)
                    }
                }
                Section("Advanced") {
                    ForEach(SettingsPane.advanced) { pane in
                        Label(pane.label, systemImage: pane.icon)
                            .tag(pane)
                    }
                }
                Section("Reset") {
                    ForEach(SettingsPane.resetSection) { pane in
                        Label(pane.label, systemImage: pane.icon)
                            .foregroundStyle(pane == .reset ? .red : .primary)
                            .tag(pane)
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 186)
        } detail: {
            Group {
                switch selection {
                case .sync:           SettingsSyncPane()
                case .about:          SettingsAboutPane()
                case .display:        SettingsDisplayPane()
                case .search:         SettingsSearchPane()
                case .projects:       SettingsProjectsPane()
                case .tags:           SettingsTagsPane()
                case .notes:          SettingsNotesPane()
                case .wordCloud:      WordCloudSettingsView()
                case .storage:        SettingsStoragePane()
                case .downloads:      SettingsAddVolumesPane()
                case .naraAPI:        SettingsNARAPane()
                case .summarization:  SettingsSummarizationPane()
                case .data:           SettingsDataPane()
                case .reset:          SettingsResetPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 680, minHeight: 520)
    }
}

// MARK: - SettingsPane

enum SettingsPane: String, Identifiable, Hashable, CaseIterable {
    case sync, about, display, search
    case projects, tags, notes, wordCloud
    case storage, downloads
    case naraAPI, summarization, data
    case reset

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sync:          return "iCloud Sync"
        case .about:         return "About"
        case .display:       return "Display"
        case .search:        return "Search"
        case .projects:      return "Projects"
        case .tags:          return "Tags"
        case .notes:         return "Notes"
        case .wordCloud:     return "Word Cloud"
        case .storage:       return "Storage"
        case .downloads:     return "Add Volumes"
        case .naraAPI:       return "NARA API"
        case .summarization: return "Summarization"
        case .data:          return "Data"
        case .reset:         return "Reset"
        }
    }

    var icon: String {
        switch self {
        case .sync:          return "icloud"
        case .about:         return "info.circle"
        case .display:       return "textformat.size"
        case .search:        return "magnifyingglass"
        case .projects:      return "folder"
        case .tags:          return "tag"
        case .notes:         return "note.text"
        case .wordCloud:     return "text.word.spacing"
        case .storage:       return "internaldrive"
        case .downloads:     return "plus.circle"
        case .naraAPI:       return "key"
        case .summarization: return "sparkles"
        case .data:          return "square.and.arrow.up"
        case .reset:         return "arrow.counterclockwise"
        }
    }

    static let general:  [SettingsPane] = [.sync, .display, .search]
    static let research: [SettingsPane] = [.projects, .tags, .notes, .wordCloud]
    static let corpus:   [SettingsPane] = [.storage, .downloads]
    static let advanced: [SettingsPane] = [.naraAPI, .summarization, .data]
    static let resetSection: [SettingsPane] = [.reset]
}

// MARK: - Shared Pane Chrome

/// Consistent header for every settings pane.
private struct PaneHeader: View {
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

                Text("\"Remember Last\" reopens documents in whichever mode — Read or Research — you last used. The in-document Read/Research control always overrides for the current document.")
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

private struct SettingsSearchPane: View {
    @AppStorage(SearchDefaults.scopeDocumentsKey) private var scopeDocuments  = true
    @AppStorage(SearchDefaults.scopeNotesKey)     private var scopeNotes      = true
    @AppStorage(SearchDefaults.scopeSummariesKey) private var scopeSummaries  = true
    @AppStorage(SearchDefaults.typeFilterKey)     private var defaultTypeFilter = "all"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PaneHeader(
                    title: "Search",
                    subtitle: "Default scope and filter settings for the Search sheet."
                )

                PaneSectionHeader(title: "Default search scope")
                Text("These toggles control which content types are searched by default. They can be overridden per-session in the Search sheet.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .padding(.bottom, 10)

                settingsPaneToggleRow(
                    label: "Documents",
                    detail: "Search indexed FRUS document text.",
                    isOn: $scopeDocuments
                )
                settingsPaneToggleRow(
                    label: "Research notes",
                    detail: "Include your research notes in search results.",
                    isOn: $scopeNotes
                )
                settingsPaneToggleRow(
                    label: "AI summaries",
                    detail: "Include generated summary text in search results.",
                    isOn: $scopeSummaries
                )

                PaneSectionHeader(title: "Default document type")
                Picker("Default document type filter", selection: $defaultTypeFilter) {
                    Text("Both").tag("all")
                    Text("Primary documents only").tag("documentsOnly")
                    Text("Editorial notes only").tag("editorialNotesOnly")
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
            .padding(24)
        }
    }
}

// MARK: - Projects Pane

private struct SettingsProjectsPane: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Project.name) private var projects: [Project]

    @State private var showEditor = false
    @State private var projectToEdit: Project? = nil
    @State private var projectToDelete: Project? = nil
    @State private var showDeleteConfirmation = false
    @State private var projectToMerge: Project? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    PaneHeader(
                        title: "Projects",
                        subtitle: "Projects let you maintain separate research contexts. Switching projects filters your notes, collections, and reading history."
                    )
                    Spacer()
                    Button {
                        projectToEdit = nil
                        showEditor = true
                    } label: {
                        Label("New project", systemImage: "plus")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                PaneSectionHeader(title: "Active context")
                activeContextRow
                    .padding(.bottom, 12)

                if !projects.isEmpty {
                    PaneSectionHeader(title: "Projects")
                    VStack(spacing: 0) {
                        ForEach(projects) { project in
                            projectRow(project)
                            if project.id != projects.last?.id {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 0.5)
                    )
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showEditor) {
            ProjectEditorView(projectToEdit: projectToEdit)
        }
        .sheet(item: $projectToMerge) { sourceProject in
            MergeProjectSheet(
                sourceProject: sourceProject,
                allProjects: projects.filter { $0.id != sourceProject.id },
                onMerge: { targetProject in
                    mergeProject(source: sourceProject, into: targetProject)
                    projectToMerge = nil
                }
            )
        }
        .confirmationDialog(
            "Delete Project?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let p = projectToDelete {
                    ProjectAdminService.delete(p, context: modelContext, appState: appState)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Activity records are kept but unlinked from this project.")
        }
    }

    private func mergeProject(source: Project, into target: Project) {
        ProjectAdminService.merge(source, into: target, context: modelContext, appState: appState)
    }

    private var activeContextRow: some View {
        HStack {
            Image(systemName: appState.activeProjectId == nil ? "globe" : "folder")
                .foregroundStyle(.secondary)
                .frame(width: 20)
            if let pid = appState.activeProjectId,
               let project = projects.first(where: { $0.id == pid }) {
                Text(project.name)
                    .font(.system(size: 13))
            } else {
                Text("Global Context")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if appState.activeProjectId != nil {
                Button("Switch to global") {
                    appState.activeProjectId = nil
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func projectRow(_ project: Project) -> some View {
        HStack(spacing: 10) {
            Button {
                appState.activeProjectId = project.id
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: appState.activeProjectId == project.id ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(appState.activeProjectId == project.id ? Color.accentColor : Color.secondary)
                        .font(.system(size: 15))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(project.name)
                            .font(.system(size: 13))
                        if let q = project.researchQuestion, !q.isEmpty {
                            Text(q)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    projectToEdit = project
                    showEditor = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button {
                    projectToMerge = project
                } label: {
                    Label("Merge into…", systemImage: "arrow.triangle.merge")
                }
                .disabled(projects.count < 2)
                Divider()
                Button(role: .destructive) {
                    projectToDelete = project
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                // "ellipsis" (three dots) + the borderless-button disclosure chevron
                // together form a single "more options" affordance (•••▾).
                Image(systemName: "ellipsis")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 14))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

// MARK: - Tags Pane

private struct SettingsTagsPane: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserTag.name) private var tags: [UserTag]

    @State private var newTagName: String = ""
    @State private var tagToRename: UserTag? = nil
    @State private var tagToDelete: UserTag? = nil
    @State private var showDeleteConfirmation = false
    @State private var tagToMerge: UserTag? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PaneHeader(
                    title: "Tags",
                    subtitle: "User tags are global labels you apply to research notes. They are not scoped to a project."
                )

                // New tag creation
                PaneSectionHeader(title: "Create tag")
                HStack(spacing: 8) {
                    TextField("Tag name", text: $newTagName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 240)
                        .onSubmit { createTag() }
                    Button("Add") { createTag() }
                        .buttonStyle(.bordered)
                        .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.bottom, 16)

                // Tag list
                PaneSectionHeader(title: "\(tags.count) tag\(tags.count == 1 ? "" : "s")")

                if tags.isEmpty {
                    Text("No tags yet. Create your first tag above.")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                } else {
                    VStack(spacing: 0) {
                        ForEach(tags) { tag in
                            tagRow(tag)
                            if tag.id != tags.last?.id {
                                Divider().padding(.leading, 12)
                            }
                        }
                    }
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 0.5)
                    )
                }
            }
            .padding(24)
        }
        .sheet(item: $tagToRename) { tag in
            TagRenameSheet(tag: tag)
        }
        .sheet(item: $tagToMerge) { sourceTag in
            MergeTagSheet(
                sourceTag: sourceTag,
                allTags: tags.filter { $0.id != sourceTag.id },
                onMerge: { targetTag in
                    mergeTag(source: sourceTag, into: targetTag)
                    tagToMerge = nil
                }
            )
        }
        .confirmationDialog(
            "Delete Tag?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let tag = tagToDelete { modelContext.delete(tag) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Notes that use this tag will no longer have it applied.")
        }
    }

    private func tagRow(_ tag: UserTag) -> some View {
        HStack {
            Text("◆")
                .font(.system(size: 11))
                .foregroundStyle(Color.accentColor)
            Text(tag.name)
                .font(.system(size: 13))
            Spacer()
            noteCount(for: tag)
            Menu {
                Button {
                    tagToRename = tag
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                Button {
                    tagToMerge = tag
                } label: {
                    Label("Merge into…", systemImage: "arrow.triangle.merge")
                }
                .disabled(tags.count < 2)
                Divider()
                Button(role: .destructive) {
                    tagToDelete = tag
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                // "ellipsis" (three dots) + the borderless-button disclosure chevron
                // together form a single "more options" affordance (•••▾).
                Image(systemName: "ellipsis")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 14))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private func noteCount(for tag: UserTag) -> some View {
        let descriptor = FetchDescriptor<ResearchNote>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        let count = all.filter { $0.userTagIds.contains(tag.id) }.count
        return Text("\(count) note\(count == 1 ? "" : "s")")
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
    }

    private func createTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let tag = UserTag(name: name)
        modelContext.insert(tag)
        newTagName = ""
    }

    private func mergeTag(source: UserTag, into target: UserTag) {
        let sourceId = source.id
        let targetId = target.id

        // Re-tag ResearchNotes (fetch all; #Predicate with array.contains crashes on transformable columns).
        let allNotes = (try? modelContext.fetch(FetchDescriptor<ResearchNote>())) ?? []
        var noteCount = 0
        for note in allNotes where note.userTagIds.contains(sourceId) {
            var ids = note.userTagIds.filter { $0 != sourceId }
            if !ids.contains(targetId) { ids.append(targetId) }
            note.userTagIds = ids
            noteCount += 1
        }

        // Re-tag DocumentTagAssignments.
        let allAssignments = (try? modelContext.fetch(FetchDescriptor<DocumentTagAssignment>())) ?? []
        var assignmentCount = 0
        for assignment in allAssignments where assignment.tagId == sourceId {
            assignment.tagId = targetId
            assignmentCount += 1
        }

        modelContext.delete(source)

        #if DEBUG
        print("[macSettings] Merged '\(source.name)' → '\(target.name)': "
              + "\(noteCount) notes, \(assignmentCount) assignments updated")
        #endif
    }
}

// MARK: - TagRenameSheet

private struct TagRenameSheet: View {
    @Environment(\.dismiss) private var dismiss
    let tag: UserTag
    @State private var name: String

    init(tag: UserTag) {
        self.tag = tag
        _name = State(initialValue: tag.name)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Rename Tag")
                .font(.system(size: 14, weight: .medium))
            TextField("Tag name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
                .onSubmit { save() }
            HStack(spacing: 8) {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Rename") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 320)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        tag.name = trimmed
        dismiss()
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

// MARK: - Storage Pane

/// Storage pane for the macOS Settings window.
///
/// Displays per-volume download/index status, storage usage bar, and bulk indexing actions.
/// An inline queue-progress card (`indexingQueueCard`) appears between the volume table and
/// the action buttons while a Settings-triggered batch is running.
///
/// Version history:
///   1.0 — New UI scaffolding
///   1.1 — Session 118: `BatchKind` state + `indexingQueueCard` for "Index Remaining" and
///          "Reindex All" runs; `indexRemaining()` iterates with per-volume position tracking;
///          `reindexAll()` marks batch state for the duration of `indexAllVolumes()`
///   1.2 — Session 118: "Delete Index & Rebuild" action — wipes all SQLite index tables via
///          `removeAllVolumesFromIndex()` then rebuilds with `indexAllVolumes()`; shows
///          confirmation alert; `.rebuildAll` BatchKind surfaces distinct header in queue card
///   1.3 — Session 130: `usageBreakdown` added (volume / index / summaries / total breakdown
///          below the usage bar, matching the iOS Storage pane); indexing controls + queue card
///          moved above the volume table so they're visible without scrolling
///   1.4 — Session 130: Phase 1 — pre-download limit gate on `SettingsAddVolumesPane`;
///          Phase 2 — `SettingsStoragePane` gains LRU/protection indicators on volume rows,
///          a storage advisory card when near/over limit, and a Manage Storage sheet with
///          removal candidates, estimated index sizes, and post-removal VACUUM
///   1.5 — Session 154: "Diagnostics" section — "Check Index Integrity" runs
///          `IndexingPipeline.checkIndexIntegrity()` and shows a green "No problems
///          found" or a list of problem descriptions with a suggestion to rebuild;
///          "Rebuild Spotlight Index" clears and re-submits the system Spotlight
///          index from `document_cache` without re-parsing XML
private struct SettingsStoragePane: View {

    // MARK: - Batch tracking

    /// Tracks the kind and progress of a Settings-triggered bulk indexing run.
    /// Set at the start of `indexRemaining()` / `reindexAll()` / `rebuildIndex()`;
    /// cleared on completion. Drives `indexingQueueCard` visibility and header label.
    private enum BatchKind {
        /// Iterating through unindexed volumes one by one; `current` is 1-based.
        case indexRemaining(current: Int, total: Int)
        /// Running `indexAllVolumes()` as a single black-box call.
        case reindexAll(total: Int)
        /// Running `removeAllVolumesFromIndex()` followed by `indexAllVolumes()`.
        case rebuildAll(total: Int)
    }

    // MARK: - Storage overhead

    /// Cross-platform index size estimate. Use `StorageReport.indexOverheadFactor`
    /// (defined in DownloadModels, calibrated with 552-volume measurements).
    static var indexOverheadFactor: Double { StorageReport.indexOverheadFactor }

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    // Queries used by Phase 2 to classify volumes as protected (have user data) or
    // removable. These are loaded only once — the query result is small for typical users.
    @Query private var allNotes: [ResearchNote]
    @Query private var allCollectionEntries: [CollectionEntry]
    @Query private var allSummaries: [GeneratedSummary]
    @Query(sort: \ReadingHistoryEntry.accessedAt, order: .reverse) private var history: [ReadingHistoryEntry]

    @State private var storageReport: StorageReport? = nil
    @State private var reindexingVolumeId: String? = nil
    /// Number of volumes that failed during the most recent indexing run.
    /// Shown as an error notice after the batch completes. Reset to nil when the next batch starts.
    @State private var bulkIndexingFailureCount: Int? = nil
    /// Non-nil while a Settings-triggered bulk indexing batch is active.
    @State private var settingsBatch: BatchKind? = nil
    /// Controls the "Delete Index & Rebuild" confirmation alert.
    @State private var showRebuildConfirmation = false
    /// Controls the Manage Storage sheet.
    @State private var showManageStorageSheet = false

    // MARK: Diagnostics state (Session 154; integrity check moved into
    // IndexHealthView in Session 162)

    /// `true` while `rebuildSpotlightIndex()` is running.
    @State private var spotlightRebuildRunning = false
    /// `true` once a Spotlight rebuild has completed successfully.
    @State private var spotlightRebuildSucceeded = false
    /// Error message from a failed Spotlight rebuild.
    @State private var spotlightRebuildError: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PaneHeader(
                    title: "Storage",
                    subtitle: "Manage volumes stored on this Mac."
                )

                // Storage report — per-category breakdown mirroring the iOS
                // Storage pane, with a Manage Storage entry for freeing space.
                PaneSectionHeader(title: "Storage used")
                if let report = storageReport {
                    usageBreakdown(report: report)
                        .padding(.bottom, 8)

                    HStack(spacing: 10) {
                        Button("Manage Storage…") {
                            showManageStorageSheet = true
                        }
                        .buttonStyle(.bordered)
                        .font(.system(size: 12))
                        .help("Review downloaded volumes with no attached notes, collections, or summaries and remove them to free space.")

                        Text("For reference: the full FRUS corpus uses ~3.4 GB of XML and ~9–10 GB of search index — approximately 13 GB total.")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.bottom, 16)
                }

                // Indexing controls — placed above the volume table so they're
                // immediately visible regardless of how many volumes are downloaded.
                PaneSectionHeader(title: "Indexing")

                // Live queue progress — shown while a Settings-triggered batch runs.
                if settingsBatch != nil || appState.currentIndexingProgress != nil {
                    indexingQueueCard
                        .padding(.bottom, 8)
                }

                // Indexing actions — primary row
                HStack(spacing: 8) {
                    Button {
                        bulkIndexingFailureCount = nil
                        Task { await indexRemaining() }
                    } label: {
                        Label("Index Remaining", systemImage: "plus.circle")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .help("Index only volumes that have not been indexed yet.")

                    Button {
                        bulkIndexingFailureCount = nil
                        Task { await reindexAll() }
                    } label: {
                        Label("Reindex All", systemImage: "arrow.clockwise")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .help("Re-index all downloaded volumes, replacing existing index data per volume.")

                    if let report = storageReport {
                        let indexed = indexedCount
                        Text("\(indexed) of \(report.perVolume.count) volume\(report.perVolume.count == 1 ? "" : "s") indexed")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }

                // Indexing actions — destructive row
                HStack(spacing: 8) {
                    Button(role: .destructive) {
                        showRebuildConfirmation = true
                    } label: {
                        Label("Delete Index & Rebuild", systemImage: "trash.circle")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(settingsBatch != nil || appState.currentIndexingProgress != nil)
                    .help("Wipe the entire search index, then rebuild it from all downloaded volumes. Use this to resolve index corruption or clean up orphaned data from deleted volumes.")

                    Text("Deletes all index tables, then re-parses every downloaded volume.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 2)

                if let failures = bulkIndexingFailureCount, failures > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                        Text("\(failures) volume\(failures == 1 ? "" : "s") failed to index. Check Console.app (subsystem: bottsywattsy.FRUS-Explorer) for details.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }

                // Diagnostics — index integrity check and Spotlight rebuild (Session 154).
                PaneSectionHeader(title: "Diagnostics")
                diagnosticsSection

                // Volume table — below the controls so short volume lists don't push
                // the indexing controls off-screen.
                PaneSectionHeader(title: "Volumes on device")
                volumeTable
            }
            .padding(24)
        }
        .task { await loadReport() }
        .sheet(isPresented: $showManageStorageSheet) {
            if let report = storageReport {
                ManageStorageSheet(
                    report: report,
                    protectedVolumeIds: protectedVolumeIds,
                    lastOpenedByVolumeId: lastOpenedByVolumeId,
                    appState: appState
                ) {
                    // Reload report after sheet-driven removals + optional VACUUM.
                    await loadReport()
                }
                .environment(appState)
                .modelContainer(modelContext.container)
            }
        }
        .alert(
            "Delete Index and Rebuild?",
            isPresented: $showRebuildConfirmation
        ) {
            Button("Delete & Rebuild", role: .destructive) {
                bulkIndexingFailureCount = nil
                Task { await rebuildIndex() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            let count = storageReport?.perVolume.count ?? 0
            Text("This will permanently delete the entire search index — FTS5 full-text rows, cross-references, page ranges, document dates, person mentions, and the document cache — then rebuild it by re-parsing all \(count) downloaded volume\(count == 1 ? "" : "s").\n\nYour research notes, highlights, summaries, collections, and tags are stored separately and will not be affected.")
        }
    }

    // MARK: - Phase 2: Protected Volumes and Removal Candidates

    /// Volume IDs that should not be offered for automatic removal because the user has
    /// research notes, collection entries, or AI summaries attached to documents in them.
    var protectedVolumeIds: Set<String> {
        var ids = Set<String>()
        allNotes.forEach           { ids.insert($0.volumeId) }
        allCollectionEntries.forEach { ids.insert($0.volumeId) }
        allSummaries.forEach       { ids.insert($0.volumeId) }
        return ids
    }

    /// Most-recent `accessedAt` date keyed by volume ID, derived from reading history.
    var lastOpenedByVolumeId: [String: Date] {
        var result: [String: Date] = [:]
        for entry in history {
            if result[entry.volumeId] == nil, let date = entry.accessedAt {
                result[entry.volumeId] = date
            }
        }
        return result
    }

    // MARK: - Private helpers

    private func formattedBytes(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    // MARK: Usage Breakdown

    /// Per-category storage breakdown shown below the usage bar.
    /// Mirrors the iOS `StorageManagementView` which uses `LabeledContent` rows.
    private func usageBreakdown(report: StorageReport) -> some View {
        VStack(spacing: 2) {
            storageRow(label: "Volume XML files",
                       bytes: report.totalVolumesBytes,
                       icon: "doc.text")
            storageRow(label: "Search index",
                       bytes: report.totalIndexBytes,
                       icon: "magnifyingglass")
            if report.totalSummariesBytes > 0 {
                storageRow(label: "AI summaries",
                           bytes: report.totalSummariesBytes,
                           icon: "sparkles")
            }
            Divider()
            HStack {
                Text("Total")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text(ByteCountFormatter.string(
                    fromByteCount: Int64(report.grandTotalBytes),
                    countStyle: .file
                ))
                .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.top, 2)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func storageRow(label: String, bytes: Int, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }

    // MARK: Volume Table

    private var volumeTable: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Volume").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                Text("Size").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary).frame(width: 60, alignment: .trailing)
                Text("Status").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
                Spacer().frame(width: 130)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.08))

            Divider()

            if let report = storageReport {
                ForEach(report.perVolume, id: \.volumeId) { entry in
                    volumeRow(entry)
                    Divider().padding(.leading, 10)
                }
            } else {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Loading…").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .padding(12)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func volumeRow(_ entry: VolumeStorageEntry) -> some View {
        let isProtected = protectedVolumeIds.contains(entry.volumeId)
        let lastOpened = lastOpenedByVolumeId[entry.volumeId]

        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(entry.volumeId)
                        .font(.system(size: 12))
                        .lineLimit(1)
                    if isProtected {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .help("This volume has attached notes, collections, or summaries and will not be suggested for automatic removal.")
                    }
                }
                if let title = appState.manifestStore.entry(forVolumeId: entry.volumeId)?.title {
                    Text(title)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                if let date = lastOpened {
                    Text("Opened \(date, style: .relative)")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                } else {
                    Text("Never opened")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // XML file size; tooltip explains the estimated index overhead.
            Text(ByteCountFormatter.string(fromByteCount: Int64(entry.volumeFileBytes), countStyle: .file))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)
                .help("XML file: \(ByteCountFormatter.string(fromByteCount: Int64(entry.volumeFileBytes), countStyle: .file)). Estimated total including search index: ~\(ByteCountFormatter.string(fromByteCount: Int64(Int(Double(entry.volumeFileBytes) * (1 + Self.indexOverheadFactor))), countStyle: .file)). The search index is typically 2.5–3× the XML file size; this figure is approximate.")

            indexStatusBadge(for: entry.volumeId)
                .frame(width: 90, alignment: .leading)

            HStack(spacing: 4) {
                if reindexingVolumeId == entry.volumeId {
                    ProgressView().controlSize(.mini)
                } else {
                    Button {
                        Task { await reindexVolume(entry.volumeId) }
                    } label: {
                        Label("Reindex", systemImage: "arrow.clockwise")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }

                Button(role: .destructive) {
                    Task { await removeVolume(entry.volumeId) }
                } label: {
                    Text("Remove")
                        .font(.system(size: 10))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .tint(.red)
            }
            .frame(width: 130, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func indexStatusBadge(for volumeId: String) -> some View {
        let isIndexed = (try? appState.indexingPipeline?.isVolumeIndexed(volumeId)) == true
        let isIndexing = appState.currentIndexingProgress?.volumeId == volumeId

        return Group {
            if isIndexing {
                Label("Indexing…", systemImage: "circle.dotted")
                    .font(.system(size: 10))
                    .foregroundStyle(.blue)
            } else if isIndexed {
                Label("Indexed", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
            } else {
                Label("Not indexed", systemImage: "circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .labelStyle(.titleAndIcon)
    }

    // MARK: - Diagnostics (Session 154)

    /// "Check Index Integrity" and "Rebuild Spotlight Index" actions, with inline
    /// result rows. Mirrors the iOS `StorageManagementView` Diagnostics section.
    @ViewBuilder
    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Index Health (Session 162): status + format version + the manual
            // integrity check, shared with the iOS Storage pane.
            IndexHealthView(actionsDisabled: settingsBatch != nil)

            HStack(spacing: 8) {
                Button {
                    Task { await runRebuildSpotlightIndex() }
                } label: {
                    if spotlightRebuildRunning {
                        HStack(spacing: 4) {
                            ProgressView().controlSize(.small)
                            Text("Rebuilding…")
                        }
                        .font(.system(size: 12))
                    } else {
                        Label("Rebuild Spotlight Index", systemImage: "magnifyingglass")
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(.bordered)
                .disabled(settingsBatch != nil || spotlightRebuildRunning || appState.indexingPipeline == nil)
                .help("Clear and re-submit the system Spotlight index from cached document text, without re-parsing volume XML.")
            }

            if spotlightRebuildSucceeded {
                Label("Spotlight index rebuilt", systemImage: "checkmark.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
            }
            if let error = spotlightRebuildError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
        }
        .padding(.bottom, 4)
    }

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
        }
        spotlightRebuildRunning = false
    }

    // MARK: - Inline Queue Progress Card

    /// Inline queue-progress card shown between the volume table and the action buttons
    /// while `settingsBatch` is non-nil or `AppState.currentIndexingProgress` is set.
    ///
    /// Shows:
    /// - "Index Remaining" mode: "Volume N of M · ~Xm remaining"
    /// - "Reindex All" mode:     "Reindexing all N volumes · ~Xm remaining"
    /// - Fallback (download-triggered or race):  "Indexing volume…"
    /// - Current volume title + progress bar + doc count + throughput
    @ViewBuilder
    private var indexingQueueCard: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Header — batch position + ETA
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                switch settingsBatch {
                case .indexRemaining(let current, let total):
                    Text(String(localized: "settings.storage.indexing.remaining",
                                defaultValue: "Volume \(current) of \(total)"))
                        .font(.system(size: 12, weight: .medium))
                case .reindexAll(let total):
                    Text(String(localized: "settings.storage.reindexing.all",
                                defaultValue: "Reindexing all \(total) volumes"))
                        .font(.system(size: 12, weight: .medium))
                case .rebuildAll(let total):
                    Text(String(localized: "settings.storage.rebuilding.all",
                                defaultValue: "Rebuilding index for all \(total) volumes"))
                        .font(.system(size: 12, weight: .medium))
                case nil:
                    Text(String(localized: "settings.storage.indexing.generic",
                                defaultValue: "Indexing…"))
                        .font(.system(size: 12, weight: .medium))
                }
                Spacer()
                if let eta = queueETAString {
                    Text(eta)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }

            // Per-volume details sourced from the live indexing progress stream.
            if let update = appState.currentIndexingProgress {
                let resolvedTitle = appState.manifestStore
                    .entry(forVolumeId: update.volumeId)?.title
                Text(resolvedTitle ?? update.volumeId)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if update.totalDocuments > 0 {
                    ProgressView(
                        value: Double(update.completedDocuments),
                        total: Double(update.totalDocuments)
                    )
                    .progressViewStyle(.linear)
                    .tint(.accentColor)

                    HStack {
                        Text(String(localized: "settings.storage.indexing.docCount",
                                    defaultValue: "\(update.completedDocuments) / \(update.totalDocuments) documents"))
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer()
                        if update.docsPerSecond > 0 {
                            Text(String(format: String(localized: "settings.storage.indexing.throughput",
                                                       defaultValue: "%.0f docs/s"),
                                        update.docsPerSecond))
                                .font(.system(size: 10).monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.mini)
                        Text(String(localized: "settings.storage.indexing.preparing",
                                    defaultValue: "Preparing…"))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.accentColor.opacity(0.18), lineWidth: 0.5)
        )
    }

    /// Combined ETA for the current batch: remaining docs in the active volume
    /// plus remaining queued volumes (for "Index Remaining" batches).
    private var queueETAString: String? {
        guard let update = appState.currentIndexingProgress else { return nil }
        var totalSeconds = 0.0

        // Remaining docs in current volume.
        if update.docsPerSecond > 0, update.totalDocuments > update.completedDocuments {
            let remaining = update.totalDocuments - update.completedDocuments
            totalSeconds += Double(remaining) / update.docsPerSecond
        }

        // For "Index Remaining" we know the per-volume position — estimate the rest.
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

    // MARK: Computed

    private var indexedCount: Int {
        guard let pipeline = appState.indexingPipeline,
              let report = storageReport else { return 0 }
        return report.perVolume.filter {
            (try? pipeline.isVolumeIndexed($0.volumeId)) == true
        }.count
    }

    // MARK: Actions

    private func loadReport() async {
        guard let dm = appState.downloadManager else { return }
        // Pass indexDirectory so the search index size (frus.db + WAL/SHM files) is
        // included in totalIndexBytes. Without it the parameter defaults to nil and the
        // index is reported as 0 bytes. The iOS StorageManagementView already passes this
        // correctly; this was the missing piece on macOS.
        storageReport = try? await dm.storageReport(indexDirectory: appState.indexDirectory)
    }

    private func reindexVolume(_ volumeId: String) async {
        guard let pipeline = appState.indexingPipeline else { return }
        reindexingVolumeId = volumeId
        try? await pipeline.indexVolume(volumeId)
        reindexingVolumeId = nil
        await loadReport()
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
            // Update position so indexingQueueCard shows "Volume N of M".
            settingsBatch = .indexRemaining(current: idx + 1, total: unindexed.count)
            do {
                try await pipeline.indexVolume(entry.volumeId)
            } catch {
                failures += 1
            }
        }
        settingsBatch = nil
        bulkIndexingFailureCount = failures > 0 ? failures : nil
        await loadReport()
    }

    private func reindexAll() async {
        guard let pipeline = appState.indexingPipeline else { return }
        let total = storageReport?.perVolume.count ?? 0
        // Mark batch state so indexingQueueCard appears for the entire run.
        settingsBatch = .reindexAll(total: total)
        // indexAllVolumes() is non-throwing: failures are emitted as .failed progress
        // events and do not propagate as thrown errors. Monitor the failure count via
        // the .failed events on AppState or check Console.app for error-level entries.
        try? await pipeline.indexAllVolumes()
        settingsBatch = nil
        // Compute the failure count post-hoc by comparing the indexed count against
        // the total downloaded count.
        if let report = storageReport {
            let downloaded = report.perVolume.count
            let indexed = indexedCount
            let failures = downloaded - indexed
            bulkIndexingFailureCount = failures > 0 ? failures : nil
        }
        await loadReport()
    }

    /// Wipes the entire search index, then rebuilds it from all downloaded volumes.
    ///
    /// Unlike `reindexAll()` (which calls `indexAllVolumes()` directly, relying on
    /// per-volume pre-deletes inside `storeIndexData`), this first calls
    /// `removeAllVolumesFromIndex()` to issue a single `DELETE FROM` per table. This
    /// guarantees a truly clean state — orphaned rows from deleted volumes, duplicate
    /// page-range rows from earlier bugs, and any FTS5 b-tree fragmentation accumulated
    /// across many incremental runs are all eliminated before the rebuild begins.
    ///
    /// User data (research notes, highlights, summaries, collections, tags) lives in
    /// SwiftData and is completely unaffected.
    private func rebuildIndex() async {
        guard let pipeline = appState.indexingPipeline else { return }
        let total = storageReport?.perVolume.count ?? 0
        settingsBatch = .rebuildAll(total: total)
        do {
            try await pipeline.removeAllVolumesFromIndex()
            appState.indexedVolumeIds = []
        } catch {
            // Wipe failed; abort rather than re-indexing on top of a partially-deleted
            // index. The error is visible in Console.app.
            settingsBatch = nil
            bulkIndexingFailureCount = total
            await loadReport()
            return
        }
        try? await pipeline.indexAllVolumes()
        settingsBatch = nil
        if let report = storageReport {
            let downloaded = report.perVolume.count
            let indexed = indexedCount
            let failures = downloaded - indexed
            bulkIndexingFailureCount = failures > 0 ? failures : nil
        }
        await loadReport()
    }

    private func removeVolume(_ volumeId: String) async {
        guard let dm = appState.downloadManager,
              let pipeline = appState.indexingPipeline else { return }
        try? await pipeline.removeVolume(volumeId)
        appState.indexedVolumeIds.remove(volumeId)
        try? await dm.deleteVolume(volumeId: volumeId)
        await loadReport()
    }
}

// MARK: - Manage Storage Sheet

/// Sheet presented from `SettingsStoragePane` when the user taps "Manage Storage…".
///
/// Lists downloaded volumes that have no attached user data (notes, collections, summaries),
/// sorted least-recently-opened first so the most-removable candidates appear at the top.
/// The user multi-selects volumes, sees a running estimate of recoverable space, and
/// confirms removal. A VACUUM is run after all removals complete to immediately shrink
/// the index file; a note explains the estimate and timing limitations.
///
/// ## Index size estimates
/// Per-volume index contribution is estimated as 40% of the XML file size
/// (`SettingsStoragePane.indexOverheadFactor`). This is the mean for the FRUS corpus;
/// individual volumes vary from roughly 30% (short volumes) to 50% (long ones). The UI
/// uses "~" prefix throughout and includes an explanation of the methodology.
private struct ManageStorageSheet: View {

    let report: StorageReport
    let protectedVolumeIds: Set<String>
    let lastOpenedByVolumeId: [String: Date]
    let appState: AppState
    let onComplete: () async -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selected: Set<String> = []
    @State private var isRemoving = false
    @State private var removalError: String? = nil

    private var candidates: [(entry: VolumeStorageEntry, lastOpened: Date?)] {
        report.perVolume
            .filter { !protectedVolumeIds.contains($0.volumeId) }
            .map { entry in (entry: entry, lastOpened: lastOpenedByVolumeId[entry.volumeId]) }
            .sorted { a, b in
                switch (a.lastOpened, b.lastOpened) {
                case (nil, nil):  return a.entry.volumeId < b.entry.volumeId
                case (nil, _):    return true   // never opened → most removable
                case (_, nil):    return false
                case (let la, let lb): return la! < lb!
                }
            }
    }

    private var estimatedRecovery: Int {
        candidates
            .filter { selected.contains($0.entry.volumeId) }
            .reduce(0) { total, c in
                total + c.entry.volumeFileBytes
                    + Int(Double(c.entry.volumeFileBytes) * SettingsStoragePane.indexOverheadFactor)
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Manage Storage")
                        .font(.headline)
                    Text("Select volumes to remove. Only volumes with no attached notes, collections, or summaries are shown.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(20)

            Divider()

            if candidates.isEmpty {
                ContentUnavailableView(
                    "No Removable Volumes",
                    systemImage: "lock.shield",
                    description: Text("Every downloaded volume has attached notes, collections, or summaries. Remove individual volumes manually from the Storage pane.")
                )
            } else {
                // Estimate explanation
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("Sizes shown are the XML file + an estimated 2.8× search index contribution (based on full-corpus measurements: ~9–10 GB index for ~3.4 GB of XML). The index stores FTS5 tokens, full document text, cross-references, and other data. Actual per-volume overhead varies from roughly 2.5× to 3×; treat these figures as approximate.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.06))

                List {
                    ForEach(candidates, id: \.entry.volumeId) { candidate in
                        candidateRow(candidate)
                    }
                }
                .listStyle(.plain)
            }

            // Footer with running total and action button
            if !candidates.isEmpty {
                Divider()
                HStack(spacing: 12) {
                    if selected.isEmpty {
                        Text("Select volumes to see estimated recovery")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("~\(ByteCountFormatter.string(fromByteCount: Int64(estimatedRecovery), countStyle: .file)) estimated recovery")
                                .font(.system(size: 12, weight: .medium))
                            Text("Actual freed space may differ; the index shrinks after removal.")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                    if let err = removalError {
                        Text(err)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                    Button {
                        Task { await performRemoval() }
                    } label: {
                        if isRemoving {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Remove \(selected.count) Volume\(selected.count == 1 ? "" : "s")")
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
        .overlay {
            if isRemoving {
                ZStack {
                    Color.black.opacity(0.2)
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("Removing volumes and compacting index…")
                            .font(.system(size: 12))
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
    private func candidateRow(_ candidate: (entry: VolumeStorageEntry, lastOpened: Date?)) -> some View {
        let volumeId = candidate.entry.volumeId
        let isSelected = selected.contains(volumeId)
        let totalEstimate = candidate.entry.volumeFileBytes
            + Int(Double(candidate.entry.volumeFileBytes) * SettingsStoragePane.indexOverheadFactor)
        let title = appState.manifestStore.entry(forVolumeId: volumeId)?.title

        Button {
            if isSelected { selected.remove(volumeId) } else { selected.insert(volumeId) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .font(.system(size: 16))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title ?? volumeId)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(volumeId)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text("~\(ByteCountFormatter.string(fromByteCount: Int64(totalEstimate), countStyle: .file))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    if let date = candidate.lastOpened {
                        Text("Opened \(date, style: .relative)")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    } else {
                        Text("Never opened")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }

    @MainActor
    private func performRemoval() async {
        guard let dm = appState.downloadManager,
              let pipeline = appState.indexingPipeline else { return }
        isRemoving = true
        removalError = nil

        for volumeId in selected {
            do {
                try await pipeline.removeVolume(volumeId)
                appState.indexedVolumeIds.remove(volumeId)
                try await dm.deleteVolume(volumeId: volumeId)
            } catch {
                removalError = "Failed to remove \(volumeId): \(error.localizedDescription)"
                isRemoving = false
                await onComplete()
                return
            }
        }

        // VACUUM after all removals to immediately compact the index file.
        // This is a blocking operation lasting a few seconds on a large database.
        try? await pipeline.vacuumIndex()

        isRemoving = false
        selected = []
        await onComplete()
        dismiss()
    }
}

// MARK: - Add Volumes Pane

/// macOS pane for sideloading, downloading, and updating FRUS volumes.
///
/// Version history:
///   1.0 — Sideload from file, download by corpus/subseries/volume, concurrency setting
///   1.1 — Session 154: added "Updates" section — `VolumeUpdateChecker` detects
///          upstream corrections to downloaded volumes via git blob SHA comparison,
///          with per-volume "Update" and "Update All" (force re-download + re-index)
private struct SettingsAddVolumesPane: View {
    @Environment(AppState.self) private var appState

    // MARK: Sideload state
    @State private var isImporting = false
    @State private var importResult: ImportResult? = nil

    // MARK: Download scope state
    private enum ScopeChoice { case corpus, subseries, volume }
    @State private var scopeChoice: ScopeChoice = .corpus
    @State private var selectedSubseries: Set<String> = []
    @State private var selectedVolumeIds: Set<String> = []
    @State private var isEnqueuing = false

    /// Seeded from UserDefaults so the picker reflects the active limit.
    @State private var concurrentDownloadLimit: Int = {
        let stored = UserDefaults.standard.integer(forKey: SettingsKeys.concurrentDownloadLimit)
        return stored > 0 ? stored : 4
    }()

    // MARK: Update detection state (Session 154)
    @State private var updatableVolumes: [UpdatableVolume] = []
    @State private var isCheckingForUpdates: Bool = false
    @State private var hasCheckedForUpdates: Bool = false


    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PaneHeader(
                    title: "Add Volumes",
                    subtitle: "Sideload a local XML file or download volumes from GitHub."
                )

                sideloadSection
                    .padding(.bottom, 24)

                Divider()
                    .padding(.bottom, 20)

                downloadSection

                Divider()
                    .padding(.top, 20)
                    .padding(.bottom, 20)

                updatesSection

                Divider()
                    .padding(.top, 20)
                    .padding(.bottom, 20)

                concurrencySection
            }
            .padding(24)
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.xml],
            allowsMultipleSelection: true
        ) { result in
            Task { await handleImport(result) }
        }
        .task {
            if appState.isOnline { await appState.manifestStore.refresh() }
        }
    }

    // MARK: - Sideload Section

    /// Concurrent-download control. Mirrors the iOS Downloads settings picker;
    /// writes `SettingsKeys.concurrentDownloadLimit` and applies immediately.
    private var concurrencySection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Concurrent downloads")
                    .font(.system(size: 13))
                Text("How many volumes download at the same time.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Concurrent downloads", selection: $concurrentDownloadLimit) {
                ForEach([1, 2, 3, 4, 6], id: \.self) { n in
                    Text("\(n)").tag(n)
                }
            }
            .frame(width: 70)
            .labelsHidden()
            .onChange(of: concurrentDownloadLimit) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: SettingsKeys.concurrentDownloadLimit)
                if let dm = appState.downloadManager {
                    Task { await dm.setConcurrencyLimit(newValue) }
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    /// Lists downloaded volumes whose upstream copy has changed since download, with
    /// per-volume "Update" and "Update All" actions. "Check for Updates" diffs each
    /// downloaded volume's git blob SHA against the live manifest (Session 154);
    /// updating force-redownloads and re-indexes, preserving user notes/tags/summaries.
    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaneSectionHeader(title: "Updates")
            Text("Checks downloaded volumes against the FRUS repository for upstream corrections. Updating re-downloads and re-indexes the volume; your notes, highlights, tags, and summaries are preserved.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .padding(.bottom, 12)

            if !updatableVolumes.isEmpty {
                VStack(spacing: 6) {
                    ForEach(updatableVolumes) { updatable in
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(updatable.entry.title)
                                    .font(.system(size: 12))
                                    .lineLimit(2)
                                Text(updatable.entry.volumeId)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Update") {
                                Task { await updateVolume(updatable) }
                            }
                            .font(.system(size: 12))
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(.bottom, 12)
            } else if hasCheckedForUpdates && !isCheckingForUpdates {
                Text("All downloaded volumes are up to date.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)
            }

            HStack(spacing: 10) {
                Button {
                    Task { await checkForUpdates() }
                } label: {
                    if isCheckingForUpdates {
                        Label("Checking…", systemImage: "arrow.triangle.2.circlepath")
                    } else {
                        Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isCheckingForUpdates || downloadedVolumes.isEmpty || appState.manifestStore.diffResult == nil)

                if !updatableVolumes.isEmpty {
                    Button {
                        Task { await updateAllVolumes() }
                    } label: {
                        Label("Update All", systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private var sideloadSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            PaneSectionHeader(title: "Sideload from file")
            Text("Import a FRUS volume XML file that you already have on disk. The file will be copied to the app's storage directory and indexed automatically.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .padding(.bottom, 6)

            HStack(spacing: 10) {
                Button {
                    isImporting = true
                } label: {
                    Label("Choose XML file…", systemImage: "doc.badge.plus")
                        .font(.system(size: 13))
                }
                .buttonStyle(.bordered)

                if let result = importResult {
                    importResultBadge(result)
                }
            }
        }
    }

    private enum ImportResult {
        case success(count: Int)
        case failure(message: String)
    }

    @ViewBuilder
    private func importResultBadge(_ result: ImportResult) -> some View {
        switch result {
        case .success(let count):
            Label("\(count) file\(count == 1 ? "" : "s") imported", systemImage: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.green)
        case .failure(let msg):
            Label(msg, systemImage: "exclamationmark.circle")
                .font(.system(size: 12))
                .foregroundStyle(.red)
        }
    }

    // MARK: - Download Section

    private var downloadSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaneSectionHeader(title: "Download from GitHub")
            Text("Choose what you'd like to download. Multiple items can be selected.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .padding(.bottom, 12)

            // Scope cards
            VStack(spacing: 6) {
                compactScopeCard(
                    isSelected: scopeChoice == .corpus,
                    systemImage: "square.stack.3d.up",
                    title: "Entire Corpus",
                    detail: "552+ volumes · ≈ 3.3 GB"
                ) { scopeChoice = .corpus; selectedSubseries = []; selectedVolumeIds = [] }

                compactScopeCard(
                    isSelected: scopeChoice == .subseries,
                    systemImage: "calendar",
                    title: "One or More Subseries",
                    detail: "Choose one or more decades or diplomatic eras."
                ) { scopeChoice = .subseries; selectedVolumeIds = [] }

                compactScopeCard(
                    isSelected: scopeChoice == .volume,
                    systemImage: "doc.text",
                    title: "Individual Volumes",
                    detail: "Select specific volumes from any subseries."
                ) { scopeChoice = .volume; selectedSubseries = [] }
            }
            .padding(.bottom, 12)

            // Conditional picker
            if scopeChoice == .subseries {
                subseriesMultiPicker
                    .padding(.bottom, 12)
            } else if scopeChoice == .volume {
                volumeGroupedMultiPicker
                    .padding(.bottom, 12)
            }

            // Enqueue button
            HStack(spacing: 10) {
                Button {
                    Task { await enqueueSelected() }
                } label: {
                    if isEnqueuing {
                        Label("Enqueueing…", systemImage: "arrow.down.circle")
                    } else {
                        Label("Download", systemImage: "arrow.down.circle")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canDownload || isEnqueuing)

                if !appState.isOnline {
                    Label("Offline — downloads will start when you reconnect.", systemImage: "wifi.slash")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func compactScopeCard(
        isSelected: Bool,
        systemImage: String,
        title: String,
        detail: String,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.system(size: 11))
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
    }

    // MARK: Subseries multi-picker

    private var subseriesMultiPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Select subseries (\(selectedSubseries.count) selected)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.4)
            List(allSubseries, id: \.self) { sub in
                Button {
                    if selectedSubseries.contains(sub) {
                        selectedSubseries.remove(sub)
                    } else {
                        selectedSubseries.insert(sub)
                    }
                } label: {
                    HStack {
                        Image(systemName: selectedSubseries.contains(sub) ? "checkmark.square.fill" : "square")
                            .foregroundStyle(selectedSubseries.contains(sub) ? Color.accentColor : Color.secondary)
                            .font(.system(size: 14))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(sub)
                                .font(.system(size: 12))
                                .foregroundStyle(.primary)
                            let count = allVolumes.filter { $0.subseries == sub }.count
                            Text("\(count) vol\(count == 1 ? "" : "s")")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .frame(height: 200)
            .background(Color.secondary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 0.5)
            )
        }
    }

    // MARK: Volume grouped multi-picker

    private var volumeGroupedMultiPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Select volumes (\(selectedVolumeIds.count) selected)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.4)
            List {
                ForEach(volumesBySubseries, id: \.subseries) { group in
                    DisclosureGroup {
                        ForEach(group.volumes) { vol in
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
                                        .font(.system(size: 13))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(vol.title)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.primary)
                                            .lineLimit(2)
                                        Text(vol.volumeId)
                                            .font(.system(size: 9))
                                            .foregroundStyle(.tertiary)
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 4)
                        }
                    } label: {
                        HStack {
                            let subsSelected = group.volumes.filter { selectedVolumeIds.contains($0.volumeId) }.count
                            Text(group.subseries)
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            if subsSelected > 0 {
                                Text("\(subsSelected)/\(group.volumes.count)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.accentColor)
                            } else {
                                Text("\(group.volumes.count) vol\(group.volumes.count == 1 ? "" : "s")")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .frame(height: 280)
            .background(Color.secondary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Derived Data

    private var allVolumes: [VolumeManifestEntry] {
        let source = appState.manifestStore.diffResult?.known ?? appState.manifestStore.bundledEntries
        return source.filter { $0.sizeBytes >= 20_000 }
    }

    private var allSubseries: [String] {
        let unique = Set(allVolumes.map(\.subseries))
        return unique.sorted { startYear($0) > startYear($1) }
    }

    private var volumesBySubseries: [(subseries: String, volumes: [VolumeManifestEntry])] {
        allSubseries.map { sub in (sub, allVolumes.filter { $0.subseries == sub }) }
    }

    private var downloadedVolumes: [VolumeManifestEntry] {
        guard let dm = appState.downloadManager else { return [] }
        return allVolumes.filter { dm.isVolumeDownloaded($0.volumeId) }
    }

    private func startYear(_ subseries: String) -> Int {
        Int(subseries.prefix(4)) ?? 0
    }

    // MARK: - Validation

    private var canDownload: Bool {
        switch scopeChoice {
        case .corpus:    return true
        case .subseries: return !selectedSubseries.isEmpty
        case .volume:    return !selectedVolumeIds.isEmpty
        }
    }

    // MARK: - Actions

    private func handleImport(_ result: Result<[URL], Error>) async {
        guard let dm = appState.downloadManager,
              let pipeline = appState.indexingPipeline else { return }

        switch result {
        case .failure:
            importResult = .failure(message: "Could not open file.")
        case .success(let urls):
            var count = 0
            for url in urls {
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }

                let volumeId = url.deletingPathExtension().lastPathComponent
                let dest = dm.volumesDirectory.appendingPathComponent("\(volumeId).xml")
                do {
                    if FileManager.default.fileExists(atPath: dest.path) {
                        try FileManager.default.removeItem(at: dest)
                    }
                    try FileManager.default.copyItem(at: url, to: dest)
                    try? (dest as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
                    try await pipeline.indexVolume(volumeId)
                    count += 1
                } catch {
                    importResult = .failure(message: "Import failed: \(error.localizedDescription)")
                    return
                }
            }
            importResult = .success(count: count)
        }
    }

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

        await performEnqueue(volumes)
    }

    /// Enqueues the given volumes without a limit check (called after user confirms override).
    private func performEnqueue(_ volumes: [VolumeManifestEntry]) async {
        guard let dm = appState.downloadManager else { return }
        for entry in volumes {
            await dm.enqueueDownload(volumeId: entry.volumeId, downloadUrl: entry.downloadUrl)
        }
    }

    // MARK: - Update Detection (Session 154)

    /// Diffs every downloaded volume's git blob SHA against the live manifest and
    /// populates `updatableVolumes` with any that have changed upstream. Runs only
    /// on explicit user request — never automatically at launch.
    private func checkForUpdates() async {
        guard let dm = appState.downloadManager,
              let liveInfo = appState.manifestStore.diffResult?.liveInfoByVolumeId else {
            return
        }
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

    /// Re-downloads `updatable` (overwriting the stale local copy) and removes it
    /// from `updatableVolumes`. `onVolumeDownloaded` re-indexes the volume
    /// automatically once the transfer completes; the UPSERT path preserves the
    /// user's notes, highlights, tags, and summaries.
    private func updateVolume(_ updatable: UpdatableVolume) async {
        guard let dm = appState.downloadManager else { return }
        await dm.enqueueDownload(volumeId: updatable.id, downloadUrl: updatable.entry.downloadUrl, force: true)
        updatableVolumes.removeAll { $0.id == updatable.id }
    }

    /// Re-downloads every volume currently listed in `updatableVolumes`.
    private func updateAllVolumes() async {
        for updatable in updatableVolumes {
            await updateVolume(updatable)
        }
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
                Text("The NARA API key is stored securely in the macOS Keychain and never leaves this device. The Source Explorer toolbar button is only shown when a key is configured.")
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

                Link("Get a NARA API key", destination: URL(string: "https://catalog.archives.gov/api/v2")!)
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

private struct SettingsSummarizationPane: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SummarizationPrompt.createdAt) private var allPrompts: [SummarizationPrompt]
    @Query(sort: \GeneratedSummary.lastModified, order: .reverse) private var allSummaries: [GeneratedSummary]

    @State private var promptToEdit: SummarizationPrompt? = nil
    @State private var showNewPromptSheet: Bool = false
    @State private var newPromptInitialTemplate: PromptTemplate? = nil

    private var standardPrompts: [SummarizationPrompt] { allPrompts.filter { $0.isStandard } }
    private var userPrompts: [SummarizationPrompt] { allPrompts.filter { !$0.isStandard } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PaneHeader(
                    title: "Summarization",
                    subtitle: "Configure AI summarization using Apple Intelligence."
                )

                // Availability notice — generation requires the on-device model;
                // prompts remain editable regardless (they sync via iCloud and are
                // used on the user's other devices).
                if !AppleIntelligenceProvider.shared.isAvailable {
                    Label("Apple Intelligence is not available on this device. Prompts can still be edited and sync to your other devices, where they are used for generation.",
                          systemImage: "exclamationmark.triangle")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 16)
                }

                // Standard Prompts
                if !standardPrompts.isEmpty {
                    PaneSectionHeader(title: "Standard Prompts")
                    promptBlock(standardPrompts) { prompt in
                        standardPromptRow(prompt)
                    }
                    .padding(.bottom, 16)
                }

                // User Prompts
                PaneSectionHeader(title: "Your Prompts")
                HStack {
                    Text("Custom prompts you create and can edit.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        newPromptInitialTemplate = nil
                        showNewPromptSheet = true
                    } label: {
                        Label("New Prompt", systemImage: "plus")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.bottom, 10)

                if userPrompts.isEmpty {
                    Text("No custom prompts yet. Click + to create one.")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                        .padding(.bottom, 16)
                } else {
                    promptBlock(userPrompts) { prompt in
                        userPromptRow(prompt)
                    }
                    .padding(.bottom, 16)
                }

                // Summary Counts
                PaneSectionHeader(title: "Summaries")
                HStack {
                    Text("Total generated")
                        .font(.system(size: 13))
                    Spacer()
                    Text("\(allSummaries.count)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .padding(.bottom, 16)

                // Background Summarization
                PaneSectionHeader(title: "Background Summarization")
                BackgroundSummarizationSettingsView()
                    .padding(.bottom, 16)
            }
            .padding(24)
        }
        .sheet(item: $promptToEdit) { prompt in
            PromptEditorView(promptToEdit: prompt)
        }
        .sheet(isPresented: $showNewPromptSheet, onDismiss: { newPromptInitialTemplate = nil }) {
            PromptEditorView(initialTemplate: newPromptInitialTemplate)
        }
    }

    // MARK: - Row builders

    private func standardPromptRow(_ prompt: SummarizationPrompt) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(prompt.name).font(.system(size: 13))
                Text(summaryCountLabel(for: prompt))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button("Use as Template") {
                newPromptInitialTemplate = templateFrom(prompt)
                showNewPromptSheet = true
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11))
            .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private func userPromptRow(_ prompt: SummarizationPrompt) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(prompt.name).font(.system(size: 13))
                Text(summaryCountLabel(for: prompt))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Menu {
                Button { promptToEdit = prompt } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button {
                    newPromptInitialTemplate = templateFrom(prompt)
                    showNewPromptSheet = true
                } label: {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }
                Divider()
                Button(role: .destructive) {
                    modelContext.delete(prompt)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                // "ellipsis" (three dots) + the borderless-button disclosure chevron
                // together form a single "more options" affordance (•••▾).
                Image(systemName: "ellipsis")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 14))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func promptBlock<Content: View>(
        _ prompts: [SummarizationPrompt],
        row: @escaping (SummarizationPrompt) -> Content
    ) -> some View {
        VStack(spacing: 0) {
            ForEach(prompts) { prompt in
                row(prompt)
                if prompt.id != prompts.last?.id {
                    Divider().padding(.leading, 12)
                }
            }
        }
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 0.5)
        )
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
            name: "Copy of \(prompt.name)",
            promptText: prompt.promptText,
            fields: fields
        )
    }

    private func summaryCountLabel(for prompt: SummarizationPrompt) -> String {
        let count = allSummaries.filter { $0.promptId == prompt.id }.count
        return "\(count) \(count == 1 ? "summary" : "summaries") generated"
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
                includeGeneratedSummaries: includeGeneratedSummaries
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
        let types: [any PersistentModel.Type] = [
            ResearchNote.self,
            GeneratedSummary.self,
            ReadingHistoryEntry.self,
            SummarizationPrompt.self,
            Collection.self,       // project's SwiftData model is Collection, not DocumentCollection
            UserTag.self,
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
private func settingsPaneToggleRow(label: String, detail: String, isOn: Binding<Bool>) -> some View {
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
