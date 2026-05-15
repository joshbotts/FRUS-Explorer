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
struct ProjectContextView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var vm = ProjectContextViewModel()

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
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "project.context.done",
                                  defaultValue: "Done")) {
                        dismiss()
                    }
                }
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
            }
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
        .onAppear { vm.load(context: modelContext) }
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
                    onActivate: { appState.activeProjectId = project.id },
                    onEdit: { vm.openEdit(project) },
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
        }
    }
}

// MARK: - ProjectRowView

private struct ProjectRowView: View {
    let project: Project
    let isActive: Bool
    let onActivate: () -> Void
    let onEdit: () -> Void
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
                    Text(entry.documentId)
                        .font(.headline)
                    Text(entry.volumeId)
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
                                             defaultValue: "Notes you write will appear here."))
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
        .overlay {
            if collections.isEmpty {
                ContentUnavailableView(
                    String(localized: "project.collections.empty.title",
                           defaultValue: "No Collections"),
                    systemImage: "books.vertical",
                    description: Text(String(localized: "project.collections.empty.detail",
                                             defaultValue: "Collections you create will appear here."))
                )
            }
        }
    }
}
