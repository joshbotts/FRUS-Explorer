// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - ProjectEditorView

/// Sheet for creating a new `Project` or editing an existing one.
///
/// Pass `projectToEdit: nil` to create a new project. Pass a `Project` instance
/// to edit it in place. The `onSaved` callback is invoked after the save so the
/// caller can reload its project list.
///
/// ## Toolbar
/// - Cancel (cancellationAction): dismisses without saving
/// - Save (confirmationAction): disabled when name is empty; persists and dismisses
///
/// ## Accessibility
/// - Name field labeled "Project name"
/// - Research question editor labeled "Research question"
///
/// Version history:
///   1.0 — Session 15: initial implementation
struct ProjectEditorView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let projectToEdit: Project?
    let onSaved: (() -> Void)?

    @State private var name: String
    @State private var researchQuestion: String

    init(projectToEdit: Project? = nil, onSaved: (() -> Void)? = nil) {
        self.projectToEdit = projectToEdit
        self.onSaved = onSaved
        _name = State(initialValue: projectToEdit?.name ?? "")
        _researchQuestion = State(initialValue: projectToEdit?.researchQuestion ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "project.editor.name.header",
                               defaultValue: "Name")) {
                    TextField(
                        String(localized: "project.editor.name.placeholder",
                               defaultValue: "Project name"),
                        text: $name
                    )
                    .accessibilityLabel(
                        String(localized: "project.editor.name.a11y",
                               defaultValue: "Project name")
                    )
                }

                Section(String(localized: "project.editor.question.header",
                               defaultValue: "Research Question")) {
                    TextEditor(text: $researchQuestion)
                        .frame(minHeight: 100)
                        .accessibilityLabel(
                            String(localized: "project.editor.question.a11y",
                                   defaultValue: "Research question")
                        )
                }
            }
            .navigationTitle(
                projectToEdit == nil
                    ? String(localized: "project.editor.title.new",
                             defaultValue: "New Project")
                    : String(localized: "project.editor.title.edit",
                             defaultValue: "Edit Project")
            )
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "project.editor.cancel",
                                  defaultValue: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "project.editor.save",
                                  defaultValue: "Save")) {
                        saveProject()
                        dismiss()
                    }
                    .disabled(
                        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 300)
        #endif
    }

    // MARK: - Save

    private func saveProject() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedQ = researchQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        if let project = projectToEdit {
            project.name = trimmedName
            project.researchQuestion = trimmedQ.isEmpty ? nil : trimmedQ
        } else {
            let project = Project(
                name: trimmedName,
                researchQuestion: trimmedQ.isEmpty ? nil : trimmedQ
            )
            modelContext.insert(project)
        }
        onSaved?()
        #if DEBUG
        print("[ProjectContext] Saved project '\(trimmedName)'")
        #endif
    }
}
