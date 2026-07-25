// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - MergeProjectSheet

/// Sheet that lets the user choose a target project to merge the source project into.
///
/// Presented by `ProjectsSettingsView` (iOS) and `SettingsProjectsPane` (macOS) when the
/// user taps "Merge into…" on a project row. Both hosts perform the merge itself through
/// `ProjectAdminService.merge`; this sheet only chooses the target and reports it back via
/// `onMerge`.
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
