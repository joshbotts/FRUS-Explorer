// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - GlobalContextView

/// Aggregated activity dashboard showing all user activity regardless of project.
///
/// ## Layout (top to bottom)
/// 1. **Summary** — total documents accessed, per-project and per-volume breakdowns
/// 2. **Research Notes** — filterable by project and/or user tag; tapping a note
///    opens the Research Note editor sheet
/// 3. **Collections** — filterable by project; tapping a collection opens the
///    Collection editor sheet
///
/// ## Filtering
/// Two independent `Picker` filters in the Notes section (project and user tag)
/// use AND logic. Either filter can be cleared to "All" independently.
///
/// ## Navigation
/// Presented modally from `ProjectContextView` when the user selects
/// "View All Activity" or from `BrowserView` in the toolbar when no project is active.
/// Within the view, a `NavigationStack` supports push navigation to document views.
///
/// ## Log prefix
/// `[GlobalContext]`
///
/// Version history:
///   1.0 — Session 25: initial implementation
///   1.1 — Session 44: Done button guarded to non-iOS (GlobalContextView is a NavigationLink
///          destination on iOS, a sheet on macOS)
struct GlobalContextView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    #if !os(iOS)
    @Environment(\.dismiss) private var dismiss
    #endif

    @State private var vm = GlobalContextViewModel()
    @State private var noteToEdit: ResearchNote? = nil
    @State private var collectionToEdit: Collection? = nil

    var body: some View {
        NavigationStack {
            List {
                summarySection
                notesSection
                collectionsSection
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.inset)
            #endif
            .navigationTitle(String(localized: "global.context.title",
                                    defaultValue: "All Activity"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if os(macOS)
            .frame(minWidth: 520, minHeight: 520)
            #endif
            .toolbar {
                #if !os(iOS)
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "global.context.done",
                                  defaultValue: "Done")) {
                        dismiss()
                    }
                }
                #endif
            }
            .task { vm.load(context: modelContext) }
            .sheet(item: $noteToEdit) { note in
                ResearchNoteEditorView(
                    documentId: note.documentId,
                    volumeId: note.volumeId,
                    activeProjectId: appState.activeProjectId,
                    noteToEdit: note,
                    indexingPipeline: appState.indexingPipeline
                )
            }
            .sheet(item: $collectionToEdit) { collection in
                CollectionEditorView(collection: collection)
            }
        }
    }

    // MARK: - Summary Section

    @ViewBuilder
    private var summarySection: some View {
        Section(String(localized: "global.context.summary.header",
                       defaultValue: "Overview")) {
            LabeledContent(
                String(localized: "global.context.summary.totalDocs",
                       defaultValue: "Documents Accessed"),
                value: "\(vm.totalDocumentsAccessed)"
            )
            .accessibilityLabel(
                String(localized: "global.context.summary.totalDocs.a11y",
                       defaultValue: "\(vm.totalDocumentsAccessed) documents accessed across all projects")
            )

            LabeledContent(
                String(localized: "global.context.summary.notes",
                       defaultValue: "Research Notes"),
                value: "\(vm.allNotes.count)"
            )

            LabeledContent(
                String(localized: "global.context.summary.collections",
                       defaultValue: "Collections"),
                value: "\(vm.allCollections.count)"
            )
        }

        if !vm.perProjectBreakdown.isEmpty {
            Section(String(localized: "global.context.breakdown.project.header",
                           defaultValue: "By Project")) {
                ForEach(vm.perProjectBreakdown) { entry in
                    HStack {
                        Text(entry.name)
                            .font(.callout)
                        Spacer()
                        Text(String(localized: "global.context.breakdown.docs",
                                    defaultValue: "\(entry.documentCount) doc\(entry.documentCount == 1 ? "" : "s")"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        String(localized: "global.context.breakdown.project.a11y",
                               defaultValue: "\(entry.name): \(entry.documentCount) document\(entry.documentCount == 1 ? "" : "s") accessed")
                    )
                }
            }
        }

        if !vm.perVolumeBreakdown.isEmpty {
            Section(String(localized: "global.context.breakdown.volume.header",
                           defaultValue: "By Volume")) {
                ForEach(vm.perVolumeBreakdown.prefix(10)) { entry in
                    HStack {
                        Text(entry.volumeId)
                            .font(.callout)
                        Spacer()
                        Text(String(localized: "global.context.breakdown.docs",
                                    defaultValue: "\(entry.documentCount) doc\(entry.documentCount == 1 ? "" : "s")"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        String(localized: "global.context.breakdown.volume.a11y",
                               defaultValue: "\(entry.volumeId): \(entry.documentCount) document\(entry.documentCount == 1 ? "" : "s") accessed")
                    )
                }
            }
        }
    }

    // MARK: - Notes Section

    @ViewBuilder
    private var notesSection: some View {
        Section {
            projectFilterPicker
            tagFilterPicker
        } header: {
            Text(String(localized: "global.context.notes.header",
                        defaultValue: "Research Notes"))
        }

        let notes = vm.filteredNotes
        Section {
            if notes.isEmpty {
                Text(String(localized: "global.context.notes.empty",
                            defaultValue: "No notes match the selected filters."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(notes) { note in
                    Button {
                        noteToEdit = note
                    } label: {
                        NoteRowView(note: note, projects: vm.projects, userTags: vm.userTags)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(noteAccessibilityLabel(note))
                    .accessibilityHint(
                        String(localized: "global.context.notes.tap.hint",
                               defaultValue: "Opens the research note editor")
                    )
                    // .isButton trait is implicit on Button; adding it explicitly is redundant (F-028).
                }
            }
        }
    }

    // MARK: - Collections Section

    @ViewBuilder
    private var collectionsSection: some View {
        Section {
            projectFilterPicker
        } header: {
            Text(String(localized: "global.context.collections.header",
                        defaultValue: "Collections"))
        }

        let collections = vm.filteredCollections
        Section {
            if collections.isEmpty {
                Text(String(localized: "global.context.collections.empty",
                            defaultValue: "No collections match the selected filter."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(collections) { collection in
                    Button {
                        collectionToEdit = collection
                    } label: {
                        CollectionRowView(collection: collection, projects: vm.projects)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(collectionAccessibilityLabel(collection))
                    .accessibilityHint(
                        String(localized: "global.context.collections.tap.hint",
                               defaultValue: "Opens the collection editor")
                    )
                    // .isButton trait is implicit on Button; adding it explicitly is redundant (F-028).
                }
            }
        }
    }

    // MARK: - Filter Pickers

    @ViewBuilder
    private var projectFilterPicker: some View {
        @Bindable var vm = vm
        Picker(
            String(localized: "global.context.filter.project.label",
                   defaultValue: "Project"),
            selection: $vm.selectedProjectFilter
        ) {
            Text(String(localized: "global.context.filter.project.all",
                        defaultValue: "All Projects")).tag(UUID?.none)
            Text(String(localized: "global.context.filter.project.untagged",
                        defaultValue: "Untagged")).tag(UUID?.some(UUID()))
            ForEach(vm.projects) { project in
                Text(project.name).tag(UUID?.some(project.id))
            }
        }
        .accessibilityLabel(
            String(localized: "global.context.filter.project.a11y",
                   defaultValue: "Filter by project")
        )
    }

    @ViewBuilder
    private var tagFilterPicker: some View {
        @Bindable var vm = vm
        Picker(
            String(localized: "global.context.filter.tag.label",
                   defaultValue: "User Tag"),
            selection: $vm.selectedUserTagFilter
        ) {
            Text(String(localized: "global.context.filter.tag.all",
                        defaultValue: "All Tags")).tag(UUID?.none)
            ForEach(vm.userTags) { tag in
                Text(tag.name).tag(UUID?.some(tag.id))
            }
        }
        .accessibilityLabel(
            String(localized: "global.context.filter.tag.a11y",
                   defaultValue: "Filter by user tag")
        )
    }

    // MARK: - Accessibility Helpers

    private func noteAccessibilityLabel(_ note: ResearchNote) -> String {
        let preview = note.bodyText.isEmpty
            ? String(localized: "global.context.note.empty", defaultValue: "Empty note")
            : note.bodyText.prefix(60).description
        return String(localized: "global.context.note.a11y",
                      defaultValue: "\(preview), from \(note.volumeId)/\(note.documentId)")
    }

    private func collectionAccessibilityLabel(_ collection: Collection) -> String {
        let count = collection.documentEntries?.count ?? 0
        return String(localized: "global.context.collection.a11y",
                      defaultValue: "\(collection.name), \(count) document\(count == 1 ? "" : "s")")
    }
}

// MARK: - NoteRowView

private struct NoteRowView: View {
    let note: ResearchNote
    let projects: [Project]
    let userTags: [UserTag]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if note.bodyText.isEmpty {
                Text(String(localized: "global.context.note.empty",
                            defaultValue: "Empty note"))
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                Text(note.bodyText)
                    .font(.callout)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
            }

            HStack(spacing: 6) {
                Text("\(note.volumeId) / \(note.documentId)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !note.projectIds.isEmpty {
                    ForEach(projectNames(for: note), id: \.self) { name in
                        Text(name)
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                } else {
                    Text(String(localized: "global.context.note.untagged",
                                defaultValue: "Untagged"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func projectNames(for note: ResearchNote) -> [String] {
        note.projectIds.compactMap { pid in
            projects.first(where: { $0.id == pid })?.name
        }
    }
}

// MARK: - CollectionRowView

private struct CollectionRowView: View {
    let collection: Collection
    let projects: [Project]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(collection.name)
                .font(.callout)
                .foregroundStyle(.primary)

            HStack(spacing: 6) {
                let count = collection.documentEntries?.count ?? 0
                Text(String(localized: "global.context.collection.count",
                            defaultValue: "\(count) document\(count == 1 ? "" : "s")"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !collection.projectIds.isEmpty {
                    ForEach(projectNames(for: collection), id: \.self) { name in
                        Text(name)
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                } else {
                    Text(String(localized: "global.context.collection.untagged",
                                defaultValue: "Untagged"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func projectNames(for collection: Collection) -> [String] {
        collection.projectIds.compactMap { pid in
            projects.first(where: { $0.id == pid })?.name
        }
    }
}
