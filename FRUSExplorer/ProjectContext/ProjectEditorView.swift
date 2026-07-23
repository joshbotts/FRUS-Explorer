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
/// ## Toolbar (iOS) / button bar (macOS)
/// - Cancel: dismisses without saving
/// - Save: disabled when name is empty; persists and dismisses
///
/// ## Platform layout
/// iOS keeps `NavigationStack` + toolbar. The macOS body follows the codebase's
/// documented sheet pattern (UI audit gap 11): plain `VStack` with a header row,
/// the shared `Form`, and a bottom Cancel/Save button bar — `NavigationStack`
/// inside a macOS sheet can push Form content outside the visible bounds.
///
/// ## Accessibility
/// - Name field labeled "Project name"
/// - Research question editor labeled "Research question"
///
/// Version history:
///   1.0 — Session 15: initial implementation
///   1.1 — Session 2026-07-04 (macOS UI audit gap 11): macOS body normalized to
///          VStack + bottom button bar; shared `editorForm` extracted
struct ProjectEditorView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

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

    /// Localized sheet title — "New Project" or "Edit Project".
    private var editorTitle: String {
        projectToEdit == nil
            ? String(localized: "project.editor.title.new",
                     defaultValue: "New Project")
            : String(localized: "project.editor.title.edit",
                     defaultValue: "Edit Project")
    }

    /// Whether Save is disabled (empty project name).
    private var saveDisabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        #if os(macOS)
        macBody
        #else
        iOSBody
        #endif
    }

    // MARK: - Platform bodies

    #if os(macOS)
    /// macOS-native sheet layout (UI audit gap 11): header row + shared form +
    /// bottom Cancel/Save bar — no `NavigationStack` chrome inside the sheet.
    private var macBody: some View {
        VStack(spacing: 0) {
            HStack {
                Text(editorTitle)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            editorForm
                .formStyle(.grouped)

            Divider()

            HStack {
                Button(String(localized: "project.editor.cancel",
                              defaultValue: "Cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(String(localized: "project.editor.save",
                              defaultValue: "Save")) {
                    saveProject()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(saveDisabled)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 420, minHeight: 300)
    }
    #else
    /// iOS sheet layout — `NavigationStack` with an inline title and toolbar.
    private var iOSBody: some View {
        NavigationStack {
            editorForm
                .navigationTitle(editorTitle)
                .navigationBarTitleDisplayMode(.inline)
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
                        .disabled(saveDisabled)
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
    #endif

    /// The name + research-question form shared by both platform bodies.
    private var editorForm: some View {
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
            // #377 Phase 5: on reaching a 2nd project, signal the one-time "open Project Home?"
            // nudge (a local-context fetch reflects the just-inserted, pre-autosave project). The
            // host gates it to once-ever via `@AppStorage`; this just carries the new project's id.
            let projectCount = (try? modelContext.fetch(FetchDescriptor<Project>()).count) ?? 0
            if projectCount >= 2 {
                appState.pendingSecondProjectNudge = project.id
            }
        }
        onSaved?()
        #if DEBUG
        print("[ProjectContext] Saved project '\(trimmedName)'")
        #endif
    }
}
