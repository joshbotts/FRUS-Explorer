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
struct FRUSSettingsView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var selection: SettingsPane = .about

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
                case .about:          SettingsAboutPane()
                case .display:        SettingsDisplayPane()
                case .search:         SettingsSearchPane()
                case .projects:       SettingsProjectsPane()
                case .tags:           SettingsTagsPane()
                case .notes:          SettingsNotesPane()
                case .storage:        SettingsStoragePane()
                case .downloads:      SettingsDownloadsPane()
                case .naraAPI:        SettingsNARAPane()
                case .summarization:  SettingsSummarizationPane()
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
    case about, display, search
    case projects, tags, notes
    case storage, downloads
    case naraAPI, summarization
    case reset

    var id: String { rawValue }

    var label: String {
        switch self {
        case .about:         return "About"
        case .display:       return "Display"
        case .search:        return "Search"
        case .projects:      return "Projects"
        case .tags:          return "Tags"
        case .notes:         return "Notes"
        case .storage:       return "Storage"
        case .downloads:     return "Downloads"
        case .naraAPI:       return "NARA API"
        case .summarization: return "Summarization"
        case .reset:         return "Reset"
        }
    }

    var icon: String {
        switch self {
        case .about:         return "info.circle"
        case .display:       return "textformat.size"
        case .search:        return "magnifyingglass"
        case .projects:      return "folder"
        case .tags:          return "tag"
        case .notes:         return "note.text"
        case .storage:       return "internaldrive"
        case .downloads:     return "arrow.down.circle"
        case .naraAPI:       return "key"
        case .summarization: return "sparkles"
        case .reset:         return "arrow.counterclockwise"
        }
    }

    static let general:  [SettingsPane] = [.about, .display, .search]
    static let research: [SettingsPane] = [.projects, .tags, .notes]
    static let corpus:   [SettingsPane] = [.storage, .downloads]
    static let advanced: [SettingsPane] = [.naraAPI, .summarization]
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
    @AppStorage("frus.display.showDocumentNumbers") private var showDocumentNumbers = true

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
                    .padding(.bottom, 16)

                PaneSectionHeader(title: "Document view")
                settingsPaneToggleRow(
                    label: "Show document numbers",
                    detail: "Displays the printed document number (e.g. \"Document 28\") in the identity line.",
                    isOn: $showDocumentNumbers
                )
            }
            .padding(24)
        }
    }
}

enum TextSizePreference: String, CaseIterable, Identifiable {
    case small, medium, large, extraLarge
    var id: String { rawValue }
    var label: String {
        switch self {
        case .small:      return "Small"
        case .medium:     return "Medium"
        case .large:      return "Large"
        case .extraLarge: return "Extra Large"
        }
    }
}

// MARK: - Search Pane

private struct SettingsSearchPane: View {
    @AppStorage("frus.search.scopeDocuments")  private var scopeDocuments  = true
    @AppStorage("frus.search.scopeNotes")      private var scopeNotes      = true
    @AppStorage("frus.search.scopeSummaries")  private var scopeSummaries  = true
    @AppStorage("frus.search.defaultTypeFilter") private var defaultTypeFilter = "all"

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
        .confirmationDialog(
            "Delete Project?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let p = projectToDelete {
                    if appState.activeProjectId == p.id { appState.activeProjectId = nil }
                    modelContext.delete(p)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Activity records are kept but unlinked from this project.")
        }
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
                Divider()
                Button(role: .destructive) {
                    projectToDelete = project
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
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
                Divider()
                Button(role: .destructive) {
                    tagToDelete = tag
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
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
        .padding(.vertical, 4)
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

private struct SettingsStoragePane: View {
    @Environment(AppState.self) private var appState
    @State private var storageReport: StorageReport? = nil
    @State private var reindexingVolumeId: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PaneHeader(
                    title: "Storage",
                    subtitle: "Manage volumes stored on this Mac."
                )

                // Storage limit
                PaneSectionHeader(title: "Storage limit")
                storageLimitRow
                    .padding(.bottom, 4)

                if let report = storageReport {
                    usageBar(report: report)
                        .padding(.bottom, 16)
                }

                // Volume table
                PaneSectionHeader(title: "Volumes on device")
                volumeTable
                    .padding(.bottom, 12)

                // Reindex all
                HStack(spacing: 10) {
                    Button {
                        Task { await reindexAll() }
                    } label: {
                        Label("Reindex all volumes", systemImage: "arrow.clockwise")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)

                    if let report = storageReport {
                        let indexed = indexedCount
                        Text("\(indexed) of \(report.perVolume.count) volume\(report.perVolume.count == 1 ? "" : "s") indexed")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(24)
        }
        .task { await loadReport() }
    }

    // MARK: Storage Limit Row

    @AppStorage("frus.storage.limitGB") private var storageLimitGB: Int = 2

    private var storageLimitRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("On-device limit")
                    .font(.system(size: 13))
                Text("App will warn before downloads exceed this threshold. Full corpus is ~3.4 GB.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Limit", selection: $storageLimitGB) {
                Text("1 GB").tag(1)
                Text("2 GB").tag(2)
                Text("3 GB").tag(3)
                Text("No limit").tag(0)
            }
            .frame(width: 100)
            .labelsHidden()
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    // MARK: Usage Bar

    private func usageBar(report: StorageReport) -> some View {
        let usedGB = Double(report.totalVolumesBytes + report.totalIndexBytes) / 1_073_741_824
        let limitGB = storageLimitGB > 0 ? Double(storageLimitGB) : 4.0
        let fraction = min(usedGB / limitGB, 1.0)

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Used: \(String(format: "%.1f", usedGB)) GB")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                if storageLimitGB > 0 {
                    Text("Limit: \(storageLimitGB) GB")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(fraction > 0.85 ? Color.orange : Color.accentColor)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 6)
        }
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
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.volumeId)
                    .font(.system(size: 12))
                    .lineLimit(1)
                if let title = appState.manifestStore.entry(forVolumeId: entry.volumeId)?.title {
                    Text(title)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(ByteCountFormatter.string(fromByteCount: Int64(entry.volumeFileBytes), countStyle: .file))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)

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
        storageReport = try? await dm.storageReport()
    }

    private func reindexVolume(_ volumeId: String) async {
        guard let pipeline = appState.indexingPipeline else { return }
        reindexingVolumeId = volumeId
        try? await pipeline.indexVolume(volumeId)
        reindexingVolumeId = nil
        await loadReport()
    }

    private func reindexAll() async {
        guard let pipeline = appState.indexingPipeline else { return }
        try? await pipeline.indexAllVolumes()
        await loadReport()
    }

    private func removeVolume(_ volumeId: String) async {
        guard let dm = appState.downloadManager,
              let pipeline = appState.indexingPipeline else { return }
        try? await pipeline.removeVolume(volumeId)
        try? await dm.deleteVolume(volumeId: volumeId)
        await loadReport()
    }
}

// MARK: - Downloads Pane

private struct SettingsDownloadsPane: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PaneHeader(
                    title: "Downloads",
                    subtitle: "Download volumes, subseries, or the entire corpus."
                )

                Text("The download manager will appear here. Use the Corpus Browser (⇧⌘B) to browse and download individual volumes.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
            }
            .padding(24)
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
    @AppStorage("frus.summarization.enabled") private var isEnabled: Bool = true
    @Query(sort: \SummarizationPrompt.name) private var prompts: [SummarizationPrompt]

    @State private var showCreatePrompt = false
    @State private var promptToEdit: SummarizationPrompt? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PaneHeader(
                    title: "Summarization",
                    subtitle: "Configure AI summarization using Apple Intelligence."
                )

                // Enable toggle
                PaneSectionHeader(title: "Feature")
                settingsPaneToggleRow(
                    label: "Enable AI summarization",
                    detail: "Show the summary block in the Document view. Requires Apple Intelligence.",
                    isOn: $isEnabled
                )
                .padding(.bottom, 12)

                if appState.summarizationService == nil {
                    Label("Apple Intelligence is not available on this device.", systemImage: "exclamationmark.triangle")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 16)
                }

                // Prompts
                PaneSectionHeader(title: "Prompts")
                HStack {
                    Text("Manage the prompts available when summarizing documents.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        showCreatePrompt = true
                    } label: {
                        Label("New prompt", systemImage: "plus")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.bottom, 10)

                if prompts.isEmpty {
                    Text("No custom prompts. A default prompt is always available.")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                } else {
                    VStack(spacing: 0) {
                        ForEach(prompts) { prompt in
                            promptRow(prompt)
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
            }
            .padding(24)
        }
        .sheet(isPresented: $showCreatePrompt) {
            SummarizationPromptEditorSheet(prompt: nil)
        }
        .sheet(item: $promptToEdit) { prompt in
            SummarizationPromptEditorSheet(prompt: prompt)
        }
    }

    private func promptRow(_ prompt: SummarizationPrompt) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(prompt.name)
                    .font(.system(size: 13))
                if !prompt.promptText.isEmpty {
                    Text(prompt.promptText)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Menu {
                Button {
                    promptToEdit = prompt
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Divider()
                Button(role: .destructive) {
                    modelContext.delete(prompt)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
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

// MARK: - SummarizationPromptEditorSheet (stub)

private struct SummarizationPromptEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let prompt: SummarizationPrompt?
    var body: some View {
        VStack(spacing: 12) {
            Text(prompt == nil ? "New Prompt" : "Edit Prompt")
                .font(.headline)
            Text("Prompt editor — full implementation in next session.")
                .foregroundStyle(.secondary)
            Button("Done") { dismiss() }
        }
        .padding(24)
        .frame(width: 480, height: 300)
    }
}

// MARK: - Reset Pane

private struct SettingsResetPane: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var showLocalResetConfirmation = false
    @State private var showFullResetConfirmation = false
    @State private var isResetting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PaneHeader(
                    title: "Reset",
                    subtitle: "Reset FRUS Explorer to its initial state."
                )

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
        isResetting = true

        // 1. Remove all downloaded volume files
        if let dm = appState.downloadManager {
            let entries = appState.manifestStore.diffResult?.known
                ?? appState.manifestStore.bundledEntries
            for entry in entries where dm.isVolumeDownloaded(entry.volumeId) {
                try? await dm.deleteVolume(volumeId: entry.volumeId)
            }
        }

        // 2. Remove the search index
        if let pipeline = appState.indexingPipeline {
            let entries = appState.manifestStore.diffResult?.known
                ?? appState.manifestStore.bundledEntries
            for entry in entries {
                try? await pipeline.removeVolume(entry.volumeId)
            }
        }

        // 3. If full reset, delete all SwiftData records
        if includeCloudKit {
            deleteAllUserData()
        }

        // 4. Clear onboarding flag — ContentRootView immediately shows OnboardingView
        appState.hasCompletedOnboarding = false
        isResetting = false

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
