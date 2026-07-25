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
///   1.2 — S-3b: a "Manage" section carries Merge and Delete as visible rows, so the two
///          destructive project actions stop being swipe- and long-press-only on iOS and
///          ellipsis-menu-only on macOS. The host still presents the merge picker.
struct ProjectEditorView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    /// The once-ever gate for the second-project nudge (#377 Phase 5), read here so the signal is
    /// set ONLY when the nudge would actually show — never left stale after it has already fired.
    @AppStorage("frus.hasShownSecondProjectNudge") private var hasShownSecondProjectNudge = false

    let projectToEdit: Project?
    let onSaved: (() -> Void)?
    /// Whether the macOS layout shows its own inline title row. True for sheet presentations (the
    /// Settings pane); the macOS New Project *window* (#377 Phase 5) passes false because its window
    /// titlebar already reads "New Project", so an inline headline would duplicate it.
    let showsInlineHeader: Bool
    /// Asked to merge this project into another (S-3b). The editor dismisses first and the host
    /// presents the picker — a sheet presented from inside a sheet is a layout hazard on macOS, and
    /// the host already owns `MergeProjectSheet`. `nil` hides the row.
    let onMergeRequested: ((Project) -> Void)?
    /// Called after the project has been deleted, so the host can clear its selection (S-3b).
    /// `nil` hides the Delete row.
    let onDeleted: (() -> Void)?
    /// How many projects exist, so Merge can disable itself when there is nothing to merge into.
    let peerProjectCount: Int

    @State private var name: String
    @State private var researchQuestion: String
    @State private var showDeleteConfirmation = false

    init(projectToEdit: Project? = nil,
         onSaved: (() -> Void)? = nil,
         showsInlineHeader: Bool = true,
         onMergeRequested: ((Project) -> Void)? = nil,
         onDeleted: (() -> Void)? = nil,
         peerProjectCount: Int = 0) {
        self.projectToEdit = projectToEdit
        self.onSaved = onSaved
        self.showsInlineHeader = showsInlineHeader
        self.onMergeRequested = onMergeRequested
        self.onDeleted = onDeleted
        self.peerProjectCount = peerProjectCount
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
            if showsInlineHeader {
                HStack {
                    Text(editorTitle)
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 12)

                Divider()
            }

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

            manageSection
        }
        .confirmationDialog(
            String(localized: "settings.projects.delete.title", defaultValue: "Delete Project?"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.projects.delete.confirm", defaultValue: "Delete"),
                   role: .destructive) {
                if let project = projectToEdit {
                    ProjectAdminService.delete(project, context: modelContext, appState: appState)
                }
                onDeleted?()
                dismiss()
            }
            Button(String(localized: "settings.projects.delete.cancel", defaultValue: "Cancel"),
                   role: .cancel) {}
        } message: {
            Text(String(localized: "settings.projects.delete.message",
                        defaultValue: "Activity records are kept but unlinked from this project."))
        }
    }

    /// Merge and Delete, as visible rows rather than a swipe or a context menu (S-3b).
    ///
    /// Before this, deleting a project on iOS meant knowing to swipe a row, and merging meant
    /// knowing to touch and hold it; the list's own footer had to explain both gestures. An action
    /// a footer has to teach is an action nobody finds. Shown only when editing an existing
    /// project — there is nothing to merge or delete while creating one.
    @ViewBuilder
    private var manageSection: some View {
        if let project = projectToEdit, onMergeRequested != nil || onDeleted != nil {
            Section {
                if let onMergeRequested {
                    Button {
                        dismiss()
                        onMergeRequested(project)
                    } label: {
                        Label(String(localized: "project.editor.merge",
                                     defaultValue: "Merge into Another Project…"),
                              systemImage: "arrow.triangle.merge")
                    }
                    .disabled(peerProjectCount < 2)
                }
                if onDeleted != nil {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label(String(localized: "project.editor.delete",
                                     defaultValue: "Delete Project"),
                              systemImage: "trash")
                    }
                }
            } header: {
                Text(String(localized: "project.editor.manage.header", defaultValue: "Manage"))
            } footer: {
                Text(peerProjectCount < 2
                     ? String(localized: "project.editor.manage.footer.only",
                              defaultValue: "Merging needs a second project to merge into. Deleting keeps your notes, collections, and history — it only unlinks them from this project.")
                     : String(localized: "project.editor.manage.footer",
                              defaultValue: "Merging moves everything filed here into the project you choose. Deleting keeps your notes, collections, and history — it only unlinks them from this project."))
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
            // #377 Phase 5 follow-up: make the newly created project the active one — creating a
            // project is an act of switching to it (most visible from the macOS Research ▸ New Project
            // command, which sits beside Switch Project). Only the create branch activates; editing an
            // existing project leaves the active project unchanged, and onboarding's default project
            // is created on a separate path.
            appState.activeProjectId = project.id
            // #377 Phase 5: on reaching a 2nd project (and only if the nudge hasn't already been
            // shown), signal the one-time "open Project Home?" nudge, carrying the new project's id.
            // The local-context fetch reflects the just-inserted, pre-autosave project. `shouldNudge`
            // is the single, unit-tested decision; checking `hasShown` here means the signal is never
            // left set after the nudge has fired.
            let projectCount = (try? modelContext.fetch(FetchDescriptor<Project>()).count) ?? 0
            if SecondProjectNudge.shouldNudge(projectCount: projectCount,
                                              alreadyShown: hasShownSecondProjectNudge) {
                appState.pendingSecondProjectNudge = project.id
            }
        }
        onSaved?()
        #if DEBUG
        print("[ProjectContext] Saved project '\(trimmedName)'")
        #endif
    }
}
