// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - ProjectContextView

/// Full project management and activity dashboard sheet.
///
/// ## Layout
/// 1. **Projects** section — global context toggle, per-project rows with
///    switch / edit / delete actions via ellipsis menu
/// 2. **Activity** section — navigation links to reading history, notes browser,
///    and collections browser; all lists filter by the currently active project
///    (or show everything in global context)
///
/// ## Global Context
/// When no project is active, the activity lists aggregate records across all
/// projects. Selecting "Global Context" sets `AppState.activeProjectId = nil`.
///
/// ## Project Deletion
/// Deleting a project removes the `Project` record but NOT the associated
/// activity records. `ReadingHistoryEntry`, `ResearchNote`, and `Collection`
/// records retain their orphaned `projectId` values and remain visible in
/// global context.
///
/// Version history:
///   1.0 — Session 15: initial implementation
///   1.1 — Session 25: add Global Context View entry point
///   1.2 — Session 44: Done button and dismiss guarded to non-iOS; GlobalContextView
///          presented as NavigationLink on iOS, sheet on macOS
///   1.3 — Session 101: Session Log NavigationLink added to activitySection
struct ProjectContextView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    #if !os(iOS)
    @Environment(\.dismiss) private var dismiss
    @State private var showGlobalContext = false
    #endif

    @State private var vm = ProjectContextViewModel()
    @State private var mergingProject: Project? = nil

    var body: some View {
        @Bindable var vm = vm
        NavigationStack {
            List {
                projectsSection
                activitySection
            }
            .navigationTitle(
                String(localized: "project.context.title",
                       defaultValue: "Projects")
            )
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if os(macOS)
            .frame(minWidth: 420, minHeight: 480)
            #endif
            .toolbar {
                #if !os(iOS)
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "project.context.done",
                                  defaultValue: "Done")) {
                        dismiss()
                    }
                }
                #endif
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        vm.openCreate()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(
                        String(localized: "project.context.add.a11y",
                               defaultValue: "New project")
                    )
                }
            }
            .sheet(isPresented: $vm.showProjectEditor) {
                ProjectEditorView(projectToEdit: vm.projectToEdit) {
                    vm.load(context: modelContext)
                }
                // ProjectEditorView reads AppState (the second-project nudge signal, #377 Phase 5);
                // re-inject it since a sheet doesn't reliably inherit it (mirrors the word-cloud sheet).
                .environment(appState)
            }
            #if !os(iOS)
            .sheet(isPresented: $showGlobalContext) {
                GlobalContextView()
            }
            #endif
            .confirmationDialog(
                String(localized: "project.context.delete.title",
                       defaultValue: "Delete Project?"),
                isPresented: $vm.showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(
                    String(localized: "project.context.delete.confirm",
                           defaultValue: "Delete"),
                    role: .destructive
                ) {
                    if let project = vm.projectPendingDeletion,
                       appState.activeProjectId == project.id {
                        appState.activeProjectId = nil
                    }
                    vm.confirmDelete(context: modelContext)
                }
                Button(
                    String(localized: "project.context.delete.cancel",
                           defaultValue: "Cancel"),
                    role: .cancel
                ) {}
            } message: {
                Text(String(localized: "project.context.delete.message",
                            defaultValue: "Activity records are kept but unlinked from this project."))
            }
        }
        .sheet(item: $mergingProject) { sourceProject in
            MergeProjectSheet(
                sourceProject: sourceProject,
                allProjects: vm.projects.filter { $0.id != sourceProject.id },
                onMerge: { targetProject in
                    mergeProject(source: sourceProject, into: targetProject)
                    mergingProject = nil
                }
            )
        }
        .onAppear { vm.load(context: modelContext) }
    }

    // MARK: - Merge Project

    /// Re-assigns all activity records that reference `source` to reference `target`,
    /// then deletes `source`. Mirrors the tag-merge pattern:
    /// - Uses in-memory fetch+filter for array columns ([UUID]) to avoid the
    ///   #Predicate transformable-array crash.
    /// - Handles scalar projectId columns with direct iteration.
    private func mergeProject(source: Project, into target: Project) {
        let sourceId = source.id
        let targetId = target.id

        // 1. ResearchNote.projectIds ([UUID] array)
        let allNotes = (try? modelContext.fetch(FetchDescriptor<ResearchNote>())) ?? []
        var noteCount = 0
        for note in allNotes where note.projectIds.contains(sourceId) {
            var ids = note.projectIds.filter { $0 != sourceId }
            if !ids.contains(targetId) { ids.append(targetId) }
            note.projectIds = ids
            noteCount += 1
        }

        // 2. Collection.projectIds ([UUID] array)
        let allCollections = (try? modelContext.fetch(FetchDescriptor<Collection>())) ?? []
        var collectionCount = 0
        for collection in allCollections where collection.projectIds.contains(sourceId) {
            var ids = collection.projectIds.filter { $0 != sourceId }
            if !ids.contains(targetId) { ids.append(targetId) }
            collection.projectIds = ids
            collectionCount += 1
        }

        // 3. GeneratedSummary.projectId (UUID?)
        let allSummaries = (try? modelContext.fetch(FetchDescriptor<GeneratedSummary>())) ?? []
        var summaryCount = 0
        for summary in allSummaries where summary.projectId == sourceId {
            summary.projectId = targetId
            summaryCount += 1
        }

        // 4. ReadingHistoryEntry.projectId (UUID?)
        let allHistory = (try? modelContext.fetch(FetchDescriptor<ReadingHistoryEntry>())) ?? []
        var historyCount = 0
        for entry in allHistory where entry.projectId == sourceId {
            entry.projectId = targetId
            historyCount += 1
        }

        // 5. Redirect active project context
        if appState.activeProjectId == sourceId {
            appState.activeProjectId = targetId
        }

        modelContext.delete(source)

        #if DEBUG
        print("[Projects] Merged '\(source.name)' → '\(target.name)': "
              + "\(noteCount) notes, \(collectionCount) collections, "
              + "\(summaryCount) summaries, \(historyCount) history entries")
        #endif
    }

    // MARK: - Projects Section

    @ViewBuilder
    private var projectsSection: some View {
        Section(String(localized: "project.context.projects.header",
                       defaultValue: "Projects")) {
            // Global context option
            Button {
                appState.activeProjectId = nil
            } label: {
                HStack {
                    Label(
                        String(localized: "project.context.global",
                               defaultValue: "Global Context"),
                        systemImage: "globe"
                    )
                    Spacer()
                    if appState.activeProjectId == nil {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                appState.activeProjectId == nil
                    ? String(localized: "project.context.global.active",
                             defaultValue: "Global Context, active")
                    : String(localized: "project.context.global.a11y",
                             defaultValue: "Global Context")
            )

            ForEach(vm.projects) { project in
                ProjectRowView(
                    project: project,
                    isActive: appState.activeProjectId == project.id,
                    canMerge: vm.projects.count >= 2,
                    onActivate: { appState.activeProjectId = project.id },
                    onEdit: { vm.openEdit(project) },
                    onMerge: { mergingProject = project },
                    onDelete: { vm.requestDelete(project) }
                )
            }
        }
    }

    // MARK: - Activity Section

    @ViewBuilder
    private var activitySection: some View {
        Section(String(localized: "project.context.activity.header",
                       defaultValue: "Activity")) {
            NavigationLink {
                ReadingHistoryListView(projectId: appState.activeProjectId)
            } label: {
                Label(
                    String(localized: "project.context.history",
                           defaultValue: "Reading History"),
                    systemImage: "clock"
                )
            }
            NavigationLink {
                NotesListView(projectId: appState.activeProjectId)
            } label: {
                Label(
                    String(localized: "project.context.notes",
                           defaultValue: "Research Notes"),
                    systemImage: "note.text"
                )
            }
            NavigationLink {
                CollectionsListView(projectId: appState.activeProjectId)
            } label: {
                Label(
                    String(localized: "project.context.collections",
                           defaultValue: "Collections"),
                    systemImage: "books.vertical"
                )
            }
            NavigationLink {
                SessionLogView()
            } label: {
                Label(
                    String(localized: "project.context.sessionLog",
                           defaultValue: "Session Log"),
                    systemImage: "clock.badge.checkmark"
                )
            }
        }

        Section {
            #if os(iOS)
            NavigationLink {
                GlobalContextView()
            } label: {
                Label(
                    String(localized: "project.context.globalContext.button",
                           defaultValue: "All Activity (Global Context)"),
                    systemImage: "globe"
                )
            }
            .accessibilityLabel(
                String(localized: "project.context.globalContext.a11y",
                       defaultValue: "View all activity across all projects")
            )
            #else
            Button {
                showGlobalContext = true
            } label: {
                Label(
                    String(localized: "project.context.globalContext.button",
                           defaultValue: "All Activity (Global Context)"),
                    systemImage: "globe"
                )
            }
            .accessibilityLabel(
                String(localized: "project.context.globalContext.a11y",
                       defaultValue: "View all activity across all projects")
            )
            #endif
        }
    }
}

// MARK: - ProjectRowView

private struct ProjectRowView: View {
    let project: Project
    let isActive: Bool
    let canMerge: Bool
    let onActivate: () -> Void
    let onEdit: () -> Void
    let onMerge: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onActivate) {
                HStack {
                    Label(project.name, systemImage: "folder")
                    if let q = project.researchQuestion, !q.isEmpty {
                        Text(q)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if isActive {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    onEdit()
                } label: {
                    Label(
                        String(localized: "project.row.edit",
                               defaultValue: "Edit"),
                        systemImage: "pencil"
                    )
                }
                Button {
                    onMerge()
                } label: {
                    Label(
                        String(localized: "project.row.merge",
                               defaultValue: "Merge into…"),
                        systemImage: "arrow.triangle.merge"
                    )
                }
                .disabled(!canMerge)
                Divider()
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label(
                        String(localized: "project.row.delete",
                               defaultValue: "Delete"),
                        systemImage: "trash"
                    )
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
            }
            .accessibilityLabel(
                "\(project.name) \(String(localized: "project.row.options", defaultValue: "options"))"
            )
        }
        .accessibilityLabel(
            isActive
                ? "\(project.name), \(String(localized: "project.row.active", defaultValue: "active project"))"
                : project.name
        )
    }
}

// MARK: - ReadingHistoryListView

private struct ReadingHistoryListView: View {
    let projectId: UUID?
    @Query(sort: \ReadingHistoryEntry.accessedAt, order: .reverse)
    private var allEntries: [ReadingHistoryEntry]

    private var entries: [ReadingHistoryEntry] {
        guard let pid = projectId else { return allEntries }
        return allEntries.filter { $0.projectId == pid }
    }

    var body: some View {
        List {
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    // Show the captured display title when available; fall back to a
                    // combined "volumeId · documentId" for pre-1.1 entries (F-021).
                    Text(entry.displayTitle ?? "\(entry.volumeId) · \(entry.documentId)")
                        .font(.headline)
                        .lineLimit(2)
                    Text(entry.volumeId)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let date = entry.accessedAt {
                        Text(date, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .navigationTitle(
            String(localized: "project.history.title",
                   defaultValue: "Reading History")
        )
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .overlay {
            if entries.isEmpty {
                ContentUnavailableView(
                    String(localized: "project.history.empty.title",
                           defaultValue: "No Reading History"),
                    systemImage: "clock",
                    description: Text(String(localized: "project.history.empty.detail",
                                             defaultValue: "Documents you read will appear here."))
                )
            }
        }
    }
}

// MARK: - NotesListView

private struct NotesListView: View {
    let projectId: UUID?
    @Query(sort: \ResearchNote.lastModified, order: .reverse)
    private var allNotes: [ResearchNote]

    private var notes: [ResearchNote] {
        guard let pid = projectId else { return allNotes }
        return allNotes.filter { $0.projectIds.contains(pid) }
    }

    var body: some View {
        List {
            ForEach(notes) { note in
                VStack(alignment: .leading, spacing: 2) {
                    if note.bodyText.isEmpty {
                        Text(String(localized: "project.notes.empty.note",
                                    defaultValue: "Empty note"))
                            .foregroundStyle(.tertiary)
                            .italic()
                    } else {
                        Text(note.bodyText)
                            .lineLimit(2)
                    }
                    Text("\(note.volumeId) / \(note.documentId)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .navigationTitle(
            String(localized: "project.notes.title",
                   defaultValue: "Research Notes")
        )
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .overlay {
            if notes.isEmpty {
                ContentUnavailableView(
                    String(localized: "project.notes.empty.title",
                           defaultValue: "No Research Notes"),
                    systemImage: "note.text",
                    description: Text(String(localized: "project.notes.empty.detail",
                                             defaultValue: "Open a document and tap Add Note to start building your research record."))
                )
            }
        }
    }
}

// MARK: - CollectionsListView

private struct CollectionsListView: View {
    let projectId: UUID?
    @Query(sort: \Collection.lastModified, order: .reverse)
    private var allCollections: [Collection]
    @State private var collectionToCreate: Collection? = nil
    @Environment(\.modelContext) private var modelContext

    private var collections: [Collection] {
        guard let pid = projectId else { return allCollections }
        return allCollections.filter { $0.projectIds.contains(pid) }
    }

    var body: some View {
        List {
            ForEach(collections) { collection in
                VStack(alignment: .leading, spacing: 2) {
                    Text(collection.name)
                        .font(.headline)
                    if let note = collection.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .navigationTitle(
            String(localized: "project.collections.title",
                   defaultValue: "Collections")
        )
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    createCollection()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(
                    String(localized: "project.collections.new.a11y",
                           defaultValue: "New collection")
                )
            }
        }
        .sheet(item: $collectionToCreate) { collection in
            CollectionEditorView(collection: collection)
        }
        .overlay {
            if collections.isEmpty {
                // actions: gives users a direct path forward from the empty state (F-020).
                ContentUnavailableView {
                    Label(
                        String(localized: "project.collections.empty.title",
                               defaultValue: "No Collections"),
                        systemImage: "books.vertical"
                    )
                } description: {
                    Text(String(localized: "project.collections.empty.detail",
                                defaultValue: "Group documents and notes together into named collections."))
                } actions: {
                    Button {
                        createCollection()
                    } label: {
                        Text(String(localized: "project.collections.empty.cta",
                                    defaultValue: "New Collection"))
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func createCollection() {
        let newCollection = Collection(name: String(localized: "project.collections.new.defaultName",
                                                    defaultValue: "Untitled Collection"))
        if let pid = projectId {
            newCollection.projectIds = [pid]
        }
        modelContext.insert(newCollection)
        collectionToCreate = newCollection
    }
}


// MARK: - MergeProjectSheet

/// Sheet that lets the user choose a target project to merge the source project into.
///
/// Presented by `ProjectContextView` and `SettingsProjectsPane` when the user taps
/// "Merge into…" on a project row. All activity records referencing the source project
/// are re-assigned to the target before the source is deleted.
///
/// ## Platform layout
/// Follows the same `#if os(macOS) macBody #else iOSBody #endif` pattern as
/// `MergeTagSheet` so the sheet uses native macOS or iOS chrome on each platform.
struct MergeProjectSheet: View {
    let sourceProject: Project
    let allProjects: [Project]
    let onMerge: (Project) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedProjectId: UUID? = nil

    var body: some View {
        #if os(macOS)
        macBody
        #else
        iOSBody
        #endif
    }

    // MARK: - macOS body

    #if os(macOS)
    private var macBody: some View {
        VStack(spacing: 0) {
            Text(String(localized: "project.merge.title", defaultValue: "Merge Project"))
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "project.merge.source.header",
                                defaultValue: "Merge \"\(sourceProject.name)\" into:"))
                        .font(.callout.weight(.medium))

                    ForEach(allProjects) { project in
                        mergeProjectRow(project: project)
                    }

                    Divider()

                    Text(String(localized: "project.merge.explanation",
                                defaultValue: "All notes, collections, summaries, and reading history assigned to \"\(sourceProject.name)\" will be re-assigned to the selected project. \"\(sourceProject.name)\" will be deleted."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            }

            Divider()

            HStack {
                Button(String(localized: "project.merge.cancel", defaultValue: "Cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(String(localized: "project.merge.confirm", defaultValue: "Merge")) {
                    if let id = selectedProjectId,
                       let target = allProjects.first(where: { $0.id == id }) {
                        onMerge(target)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(selectedProjectId == nil)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 400, minHeight: 280)
    }
    #endif

    // MARK: - iOS body

    #if os(iOS)
    private var iOSBody: some View {
        NavigationStack {
            Form {
                Section(String(localized: "project.merge.source.header",
                               defaultValue: "Merge \"\(sourceProject.name)\" into:")) {
                    ForEach(allProjects) { project in
                        mergeProjectRow(project: project)
                    }
                }

                Text(String(localized: "project.merge.explanation",
                            defaultValue: "All notes, collections, summaries, and reading history assigned to \"\(sourceProject.name)\" will be re-assigned to the selected project. \"\(sourceProject.name)\" will be deleted."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle(String(localized: "project.merge.title",
                                    defaultValue: "Merge Project"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "project.merge.cancel",
                                  defaultValue: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "project.merge.confirm",
                                  defaultValue: "Merge")) {
                        if let id = selectedProjectId,
                           let target = allProjects.first(where: { $0.id == id }) {
                            onMerge(target)
                        }
                    }
                    .disabled(selectedProjectId == nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    #endif

    // MARK: - Shared row

    private func mergeProjectRow(project: Project) -> some View {
        let isSelected = selectedProjectId == project.id
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                if let q = project.researchQuestion, !q.isEmpty {
                    Text(q).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedProjectId = project.id }
        .accessibilityLabel(project.name)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
