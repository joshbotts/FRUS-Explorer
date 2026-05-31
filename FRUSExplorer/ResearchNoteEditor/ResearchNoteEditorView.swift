// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData

// MARK: - ResearchNoteEditorView

/// Sheet-based editor for creating or editing a `ResearchNote`.
///
/// ## Layout (top to bottom in Form)
/// 1. Note body — `TextEditor` for free-form / Markdown text
/// 2. Tags — toggle existing `UserTag`s; create new tags inline
/// 3. Projects — toggle which projects this note appears in
/// 4. Generated Summaries — insert promoted summary text into the body
///
/// ## Toolbar
/// - Discard (cancellationAction): dismisses without saving
/// - Save (confirmationAction): persists and dismisses
/// - Delete (destructiveAction): deletes existing note and dismisses (edit mode only)
///
/// ## Accessibility
/// - TextEditor is labeled "Research note body"
/// - Each tag Toggle uses `"\(name), user tag"` / `"\(name), project tag"` labels
///
/// Version history:
///   1.0 — Session 14: initial implementation
struct ResearchNoteEditorView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var vm: ResearchNoteEditorViewModel
    private let indexingPipeline: IndexingPipeline?
    /// When non-nil, the saved note's UUID is written back to `DocumentHighlight.noteId`
    /// for the highlight with this ID. Set when the editor is opened from a selected passage.
    private let linkedHighlightId: UUID?

    init(
        documentId: String,
        volumeId: String,
        activeProjectId: UUID?,
        noteToEdit: ResearchNote? = nil,
        linkedHighlightId: UUID? = nil,
        indexingPipeline: IndexingPipeline? = nil
    ) {
        _vm = State(initialValue: ResearchNoteEditorViewModel(
            documentId: documentId,
            volumeId: volumeId,
            activeProjectId: activeProjectId,
            noteToEdit: noteToEdit
        ))
        self.linkedHighlightId = linkedHighlightId
        self.indexingPipeline = indexingPipeline
    }

    var body: some View {
        #if os(macOS)
        macBody
        #else
        iOSBody
        #endif
    }

    // MARK: - macOS Body
    // NavigationStack inside a macOS sheet can push Form content outside the visible
    // bounds. Use a plain VStack with explicit button bar instead.

    #if os(macOS)
    private var macBody: some View {
        VStack(spacing: 0) {
            HStack {
                Text(vm.noteToEdit == nil
                     ? String(localized: "note.editor.title.new", defaultValue: "New Research Note")
                     : String(localized: "note.editor.title.edit", defaultValue: "Edit Note"))
                    .font(.headline)
                Spacer()
                if vm.noteToEdit != nil {
                    Button(String(localized: "note.editor.toolbar.delete", defaultValue: "Delete"),
                           role: .destructive) {
                        vm.delete(context: modelContext)
                        dismiss()
                    }
                    .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            Form {
                noteBodySection
                userTagsSection
                projectTagsSection
                if !vm.availableSummaries.isEmpty {
                    summariesSection
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button(String(localized: "note.editor.toolbar.discard", defaultValue: "Discard")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(String(localized: "note.editor.toolbar.save", defaultValue: "Save")) {
                    if let noteId = vm.save(context: modelContext) {
                        appState.logEvent(.noteSave(
                            noteId: noteId,
                            documentId: vm.documentId,
                            volumeId: vm.volumeId
                        ))
                        linkNoteToHighlight(noteId: noteId)
                    }
                    // Explicit save ensures the persistent store is updated before dismiss()
                    // animates. Without this, the Research window's @Query (which uses a
                    // different ModelContext on macOS) may not see the change until SwiftData's
                    // auto-save fires — which can be several seconds later.
                    try? modelContext.save()
                    pushNoteToFTS5()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 520, minHeight: 440)
        .onAppear { vm.load(context: modelContext) }
    }
    #endif

    // MARK: - iOS Body

    private var iOSBody: some View {
        NavigationStack {
            Form {
                noteBodySection
                userTagsSection
                projectTagsSection
                if !vm.availableSummaries.isEmpty {
                    summariesSection
                }
            }
            .navigationTitle(
                vm.noteToEdit == nil
                    ? String(localized: "note.editor.title.new",
                             defaultValue: "New Research Note")
                    : String(localized: "note.editor.title.edit",
                             defaultValue: "Edit Note")
            )
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { editorToolbar }
        }
        .onAppear { vm.load(context: modelContext) }
    }

    // MARK: - Note Body

    @ViewBuilder
    private var noteBodySection: some View {
        @Bindable var vm = vm
        Section(String(localized: "note.editor.body.header", defaultValue: "Note")) {
            TextEditor(text: $vm.bodyText)
                .frame(minHeight: 180)
                .accessibilityLabel(
                    String(localized: "note.editor.body.a11y",
                           defaultValue: "Research note body")
                )
        }
    }

    // MARK: - User Tags

    @ViewBuilder
    private var userTagsSection: some View {
        @Bindable var vm = vm
        Section(String(localized: "note.editor.userTags.header", defaultValue: "Tags")) {
            ForEach(vm.availableUserTags) { tag in
                Toggle(
                    tag.name,
                    isOn: Binding(
                        get: { vm.userTagIds.contains(tag.id) },
                        set: { _ in vm.toggleUserTag(tag.id) }
                    )
                )
                .accessibilityLabel("\(tag.name), user tag")
            }
            HStack {
                TextField(
                    String(localized: "note.editor.newTag.placeholder",
                           defaultValue: "New tag name"),
                    text: $vm.newTagName
                )
                .onSubmit { vm.createAndAddTag(context: modelContext) }
                Button(String(localized: "note.editor.newTag.add",
                              defaultValue: "Add")) {
                    vm.createAndAddTag(context: modelContext)
                }
                .disabled(
                    vm.newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
    }

    // MARK: - Project Tags

    @ViewBuilder
    private var projectTagsSection: some View {
        Section(String(localized: "note.editor.projects.header",
                       defaultValue: "Projects")) {
            if vm.availableProjects.isEmpty {
                Text(String(localized: "note.editor.projects.empty",
                            defaultValue: "No projects yet."))
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(vm.availableProjects) { project in
                    Toggle(
                        project.name,
                        isOn: Binding(
                            get: { vm.projectIds.contains(project.id) },
                            set: { _ in vm.toggleProjectTag(project.id) }
                        )
                    )
                    .accessibilityLabel("\(project.name), project tag")
                }
            }
        }
    }

    // MARK: - Generated Summaries

    @ViewBuilder
    private var summariesSection: some View {
        Section(String(localized: "note.editor.summaries.header",
                       defaultValue: "Generated Summaries")) {
            ForEach(vm.availableSummaries) { summary in
                SummaryPromotionRow(
                    summary: summary,
                    isPromoted: vm.selectedSummaryIds.contains(summary.id),
                    onPromote: { vm.promoteSummary(summary) },
                    onDemote: { vm.demoteSummary(summaryId: summary.id) }
                )
            }
        }
    }

    // MARK: - FTS5 Sync

    /// Pushes the current note body and tags into the FTS5 index so changes are
    /// searchable in the current session without waiting for a relaunch.
    private func linkNoteToHighlight(noteId: UUID) {
        guard let hlId = linkedHighlightId else { return }
        let descriptor = FetchDescriptor<DocumentHighlight>(
            predicate: #Predicate { $0.id == hlId }
        )
        guard let highlight = try? modelContext.fetch(descriptor).first else { return }
        highlight.noteId = noteId
    }

    private func pushNoteToFTS5() {
        guard let pipeline = indexingPipeline else { return }
        let vid = vm.volumeId
        let did = vm.documentId
        let text = vm.bodyText
        let tagString = vm.userTagIds.map(\.uuidString).joined(separator: " ")
        Task {
            try? await pipeline.updateNoteText(
                volumeId: vid, documentId: did,
                bodyText: text,
                userTagIds: tagString.isEmpty ? nil : tagString
            )
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(String(localized: "note.editor.toolbar.discard",
                          defaultValue: "Discard")) {
                dismiss()
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(String(localized: "note.editor.toolbar.save",
                          defaultValue: "Save")) {
                if let noteId = vm.save(context: modelContext) {
                    appState.logEvent(.noteSave(
                        noteId: noteId,
                        documentId: vm.documentId,
                        volumeId: vm.volumeId
                    ))
                    linkNoteToHighlight(noteId: noteId)
                }
                try? modelContext.save()   // ensure @Query in Research view updates promptly
                pushNoteToFTS5()
                dismiss()
            }
        }
        if vm.noteToEdit != nil {
            ToolbarItem(placement: .destructiveAction) {
                Button(
                    String(localized: "note.editor.toolbar.delete",
                           defaultValue: "Delete"),
                    role: .destructive
                ) {
                    vm.delete(context: modelContext)
                    dismiss()
                }
            }
        }
    }
}

// MARK: - SummaryPromotionRow

private struct SummaryPromotionRow: View {
    let summary: GeneratedSummary
    let isPromoted: Bool
    let onPromote: () -> Void
    let onDemote: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(summary.responseText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            HStack {
                Spacer()
                if isPromoted {
                    Button(
                        String(localized: "note.editor.summary.remove",
                               defaultValue: "Remove from note"),
                        role: .destructive
                    ) { onDemote() }
                    .font(.caption)
                    .buttonStyle(.borderless)
                } else {
                    Button(
                        String(localized: "note.editor.summary.insert",
                               defaultValue: "Insert into note")
                    ) { onPromote() }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
