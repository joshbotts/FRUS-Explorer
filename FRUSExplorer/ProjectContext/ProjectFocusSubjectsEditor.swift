// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - ProjectFocusSubjectsEditor

/// Edits a project's discovery-focus subjects (#377 Phase 2b). The chosen subjects are
/// stored in `Project.defaultSubjectTagIds` (revived against the volume-subject-profile
/// vocabulary) and resolve, in Mode A search, to the set of volumes those subjects are
/// characteristic of.
///
/// Shown as a sheet from Project Home. Selection saves live (toggling writes straight to the
/// model). Pre-seeded with subjects suggested from the volumes the project already engages.
///
/// Version history:
///   1.0 — #377 Phase 2b: initial implementation
struct ProjectFocusSubjectsEditor: View {

    /// The project whose focus is being edited; `defaultSubjectTagIds` is written live. Held by id
    /// and re-resolved through `@Query` (not a live `@Bindable` reference), so a deletion from
    /// another window/scene can't leave this sheet holding a deleted model to trap on.
    let projectId: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// All projects, filtered to `projectId` in `project`. Reactive: the row drops out on deletion.
    @Query private var projects: [Project]

    /// The project being edited, or `nil` if it was deleted while the sheet was open.
    private var project: Project? { projects.first { $0.id == projectId } }

    /// The bundled subject vocabulary + resolver, or `nil` when unavailable.
    private let profiles = VolumeSubjectProfilesStore.shared

    /// Live search text filtering the full vocabulary.
    @State private var searchText = ""

    /// The volumes the project engages, loaded off the main thread so a large library never
    /// blocks sheet presentation (#377 Phase 2b, following the Phase-2a freeze fix). Seeds
    /// the suggestions once available.
    @State private var engagedVolumeIds: Set<String> = []

    var body: some View {
        NavigationStack {
            Group {
                if let project, let profiles {
                    content(profiles, project)
                } else {
                    ContentUnavailableView(
                        String(localized: "project.focus.unavailable.title",
                               defaultValue: "Subjects Unavailable"),
                        systemImage: "tag.slash",
                        description: Text(String(localized: "project.focus.unavailable.detail",
                                                 defaultValue: "The subject index could not be loaded."))
                    )
                }
            }
            .navigationTitle(String(localized: "project.focus.title", defaultValue: "Focus Subjects"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "project.focus.done", defaultValue: "Done")) { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 560)
        #endif
        .task(id: projectId) {
            engagedVolumeIds = await ProjectEngagedDocuments.engagedVolumeIds(
                forProject: projectId, container: modelContext.container)
        }
        // Dismiss if the project is deleted from another window while this sheet is open.
        .onChange(of: project?.id) { _, id in if id == nil { dismiss() } }
    }

    @ViewBuilder
    private func content(_ profiles: VolumeSubjectProfiles, _ project: Project) -> some View {
        let chosen = Set(project.defaultSubjectTagIds)
        let suggestions = ProjectFocusSuggestions.suggestions(
            engagedVolumeIds: engagedVolumeIds, profiles: profiles, excluding: chosen)

        List {
            if !chosen.isEmpty {
                Section(String(localized: "project.focus.selected", defaultValue: "Focus subjects")) {
                    ForEach(profiles.allSubjects.filter { chosen.contains($0.ref) }) { subject in
                        subjectRow(subject, isSelected: true, project: project)
                    }
                }
            }

            if searchText.isEmpty && !suggestions.isEmpty {
                Section {
                    ForEach(suggestions) { subject in
                        subjectRow(subject, isSelected: false, project: project)
                    }
                } header: {
                    Text(String(localized: "project.focus.suggested", defaultValue: "Suggested from your volumes"))
                } footer: {
                    Text(String(localized: "project.focus.suggested.detail",
                                defaultValue: "Subjects that recur across the volumes you’ve already collected, annotated, or opened in this project."))
                }
            }

            Section(String(localized: "project.focus.all", defaultValue: "All subjects")) {
                let matches = filteredSubjects(profiles)
                if matches.isEmpty {
                    Text(String(localized: "project.focus.noMatches", defaultValue: "No subjects match."))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(matches) { subject in
                        subjectRow(subject, isSelected: chosen.contains(subject.ref), project: project)
                    }
                }
            }
        }
        .searchable(text: $searchText,
                    prompt: String(localized: "project.focus.search", defaultValue: "Search subjects"))
    }

    /// The full vocabulary filtered by `searchText` (name/category/subcategory match),
    /// capped so a blank search doesn't render thousands of rows at once.
    private func filteredSubjects(_ profiles: VolumeSubjectProfiles) -> [VolumeSubjectProfiles.SubjectOption] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return Array(profiles.allSubjects.prefix(50)) }
        return profiles.allSubjects.filter {
            $0.name.lowercased().contains(query)
                || $0.category.lowercased().contains(query)
                || $0.subcategory.lowercased().contains(query)
        }
    }

    @ViewBuilder
    private func subjectRow(_ subject: VolumeSubjectProfiles.SubjectOption, isSelected: Bool, project: Project) -> some View {
        Button {
            toggle(subject.ref, in: project)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(subject.name)
                        .foregroundStyle(.primary)
                    Text("\(subject.category) · \(subject.subcategory)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(subject.volumeCount == 1
                     ? String(localized: "project.focus.volumeCount.one", defaultValue: "1 volume")
                     : String(localized: "project.focus.volumeCount.other", defaultValue: "\(subject.volumeCount) volumes"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Adds or removes a subject ref from the project's focus (live save).
    private func toggle(_ ref: String, in project: Project) {
        // Reassign the whole array — Project's array `didSet` (and thus `lastModified` / CloudKit
        // last-write-wins) does NOT fire on an in-place `remove`/`append` (see Project.swift).
        var ids = project.defaultSubjectTagIds
        if let index = ids.firstIndex(of: ref) {
            ids.remove(at: index)
        } else {
            ids.append(ref)
        }
        project.defaultSubjectTagIds = ids
    }
}
