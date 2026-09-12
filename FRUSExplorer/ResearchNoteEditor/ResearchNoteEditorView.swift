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
///   1.1 — Session 2026-07-04 (macOS UI audit C1): on macOS the document-window
///          entry points present this editor in the `frus.noteComposer` utility
///          window (`NoteComposerWindowView` below) instead of a modal sheet, so
///          the passage being annotated stays readable while typing. The view
///          itself is unchanged — `dismiss()` closes the sheet on iOS and the
///          composer window on macOS. Sheet presentations remain on iOS and in
///          macOS list-management surfaces (Settings notes list, All Activity).
struct ResearchNoteEditorView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var vm: ResearchNoteEditorViewModel

    /// Whether the body is edited as rich text (#1275). Device-local on purpose — see
    /// ``noteBodySection``. Defaults ON, so the feature is discoverable without a settings visit.
    @AppStorage(SettingsKeys.noteEditorRichText) private var richTextEnabled = true
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
                        try? modelContext.save()   // flush so cross-context @Query (Research window, Project Home seed) sees the removal promptly, mirroring Save
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
                    // Wave R-2a / contract D2: the `.noteSave` research event is gone. It was
                    // redundant — `ResearchNote` carries `createdAt` and `lastModified` of its own
                    // — and nothing but the session log ever read it.
                    if let noteId = vm.save(context: modelContext) {
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
            // #861: the note BODY is a multi-line TextEditor, where Return inserts a newline by design and
            // therefore can never double as dismissal.
            .keyboardDismissBar()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { editorToolbar }
        }
        .onAppear { vm.load(context: modelContext) }
    }

    // MARK: - Note Body

    /// The note body — rich text since #1275, plain `TextEditor` when the reader turns it off.
    ///
    /// ## Why the formatting is optional at all
    /// #1275 asks for "optional rich text controls", and the option earns its keep: the macOS
    /// formatting bar costs a row of chrome above a field that is often three words long, and a
    /// reader who never formats anything should not pay for it. The preference is device-local —
    /// whether this Mac shows a formatting bar is a property of how this reader works here, not of
    /// the research, which is the same line `autoDownloadSemanticShards` draws.
    ///
    /// ## What is stored either way
    /// `RichTextEditor` hands back `(rtf, plain)` on every edit and both are kept: `richText` is
    /// what this editor reloads, `bodyText` is what search, the exports, Zotero and all five in-app
    /// previews read. Turning the switch OFF discards nothing by itself — the reader may turn it
    /// straight back on — but the first plain keystroke goes through `setPlainBody`, which drops the
    /// formatted copy it has just made stale. Without that the rich editor would prefer the old RTF
    /// on reopen and show the reader yesterday's prose, then overwrite today's with it on the next
    /// keystroke.
    ///
    /// ## `.id(vm.bodyRevision)`
    /// `RichTextEditor` loads `initialRTF` ONCE by design. The Insert-summary button writes the
    /// body from code, which that design cannot see, so the counter remounts the editor exactly
    /// when — and only when — something other than typing changed the text.
    @ViewBuilder
    private var noteBodySection: some View {
        @Bindable var vm = vm
        Section {
            if richTextEnabled {
                RichTextEditor(initialRTF: vm.richText, plainFallback: vm.bodyText) { rtf, plain in
                    vm.richText = rtf
                    vm.bodyText = plain
                }
                .id(vm.bodyRevision)
                .frame(minHeight: 180)
                .accessibilityLabel(
                    String(localized: "note.editor.body.a11y",
                           defaultValue: "Research note body")
                )
            } else {
                TextEditor(text: Binding(get: { vm.bodyText },
                                         set: { vm.setPlainBody($0) }))
                    .frame(minHeight: 180)
                    .accessibilityLabel(
                        String(localized: "note.editor.body.a11y",
                               defaultValue: "Research note body")
                    )
            }
        } header: {
            HStack {
                Text(String(localized: "note.editor.body.header", defaultValue: "Note"))
                Spacer()
                Toggle(String(localized: "note.editor.body.rich",
                              defaultValue: "Formatting"), isOn: $richTextEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                    .accessibilityLabel(String(localized: "note.editor.body.rich.a11y",
                                               defaultValue: "Formatted text"))
            }
        }
    }

    // MARK: - User Tags

    @ViewBuilder
    private var userTagsSection: some View {
        @Bindable var vm = vm
        NoteAssignmentPicker(
            title: String(localized: "note.editor.userTags.header", defaultValue: "Tags"),
            items: vm.availableUserTags.map { .init(id: $0.id, name: $0.name) },
            selection: Binding(get: { vm.userTagIds }, set: { vm.userTagIds = $0 }),
            pickerTitle: String(localized: "note.editor.userTags.picker", defaultValue: "Tags"),
            emptySelectionLabel: String(localized: "note.editor.userTags.none",
                                        defaultValue: "No tags"),
            emptyCatalogLabel: String(localized: "note.editor.userTags.empty",
                                      defaultValue: "No tags yet — add one below."),
            orderedList: .tags)

        // The create field stays in the editor rather than moving into the picker sheet: naming a
        // new tag is how most of them get made, and burying it one sheet deeper would cost the
        // commonest action to save the rarer one.
        Section {
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
        @Bindable var vm = vm
        NoteAssignmentPicker(
            title: String(localized: "note.editor.projects.header", defaultValue: "Projects"),
            items: vm.availableProjects.map { .init(id: $0.id, name: $0.name) },
            selection: Binding(get: { vm.projectIds }, set: { vm.projectIds = $0 }),
            pickerTitle: String(localized: "note.editor.projects.picker",
                                defaultValue: "Projects"),
            emptySelectionLabel: String(localized: "note.editor.projects.none",
                                        defaultValue: "No projects"),
            emptyCatalogLabel: String(localized: "note.editor.projects.empty",
                                      defaultValue: "No projects yet."),
            orderedList: .projects)
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
        // **Text only, and the `userTagIds:` overload must never be called from here.**
        //
        // NOTE, because the fix is narrower than it looks: `note_text` — the argument that REMAINS —
        // is a per-document column too, and this still writes one note's body into it. A document
        // can carry several notes, so all but one are invisible to search and the boot replay picks
        // the winner in unsorted fetch order. That is the same shape as the tag defect below and it
        // is NOT fixed here: collapsing many notes into one indexed text is a search-behaviour
        // decision with its own questions (what separator, what happens on delete, whether the index
        // version must move). Tracked separately; do not read the comment below as covering it.
        // `user_tag_ids` is a per-DOCUMENT column whose authoritative writer is
        // `UserTagPickerSheet.saveAndDismiss`, which sends the document's whole assigned set.
        // This editor knows only ONE note's tags, so passing them wrote a narrower set over a
        // wider one — and a note with no tags of its own passed `nil`, which the column binder
        // writes as SQL NULL rather than skipping, erasing the document's tags outright. Search
        // opts into this column, so the damage showed up as search-by-tag missing documents until
        // the next launch's replay put them back. The sibling defect in `CollectionEntryRows` was
        // fixed the same way, and the text-only overload exists precisely for callers like this.
        Task {
            try? await pipeline.updateNoteText(volumeId: vid, documentId: did, bodyText: text)
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
                // Wave R-2a / contract D2: no `.noteSave` event — see the macOS toolbar above.
                if let noteId = vm.save(context: modelContext) {
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
                    try? modelContext.save()   // flush so cross-context @Query (Research window, Project Home seed) sees the removal promptly, mirroring Save
                    dismiss()
                }
            }
        }
    }
}

// MARK: - NoteComposerRequest

/// The window value for the macOS research-note composer window group
/// (`frus.noteComposer`, UI audit C1): the document context a note is composed
/// against, plus the optional existing note to edit or highlight to link.
///
/// Carried as the value of a `WindowGroup(for: NoteComposerRequest.self)` and
/// opened via `openWindow(value:)` (#363 — replaces the old
/// `AppState.pendingNoteComposer` hand-off). Being value-based keeps the composer
/// off the macOS Window menu and lets the window restore itself.
///
/// ## Identity (window reuse)
/// All stored properties are identity fields, so SwiftUI reuses an existing
/// composer window whenever an equal request is opened and mints a new one only
/// for a genuinely different target — the same contract `DocumentWindowID` relies
/// on. Concretely: opening the composer twice for the same document (or the same
/// existing `noteId`, or the same `linkedHighlightId`) focuses the window already
/// open rather than stacking a second editor over the same SwiftData store, while
/// editing two *different* notes gives two side-by-side windows. There is
/// deliberately **no** per-open nonce — a nonce would make every request unique
/// and spawn a duplicate window on every "Add note" click.
///
/// Declared outside `#if os(macOS)` because it is referenced from cross-platform
/// call sites; the window group itself is macOS-only (iOS keeps its editor sheets).
///
/// Version history:
///   1.0 — Session 2026-07-04 (macOS UI audit C1): initial implementation
///   1.1 — #363: migrated from `pendingNoteComposer` to value-based `WindowGroup`
///         (`Codable`/`Hashable`); removes the composer from the Window menu.
///         Identity is now the semantic target (no `handoffId` nonce), so the
///         window is reused per target instead of duplicated per open.
struct NoteComposerRequest: Codable, Equatable, Hashable, Sendable {
    /// The document the note is attached to.
    let documentId: String
    /// The volume containing `documentId`.
    let volumeId: String
    /// The `ResearchNote.id` of an existing note to edit, or `nil` to create a new note.
    let noteId: UUID?
    /// The `DocumentHighlight.id` a newly saved note should be linked back to, or `nil`.
    let linkedHighlightId: UUID?

    /// Creates a request describing the composer's target.
    init(documentId: String,
         volumeId: String,
         noteId: UUID? = nil,
         linkedHighlightId: UUID? = nil) {
        self.documentId = documentId
        self.volumeId = volumeId
        self.noteId = noteId
        self.linkedHighlightId = linkedHighlightId
    }
}

// MARK: - NoteComposerWindowView

#if os(macOS)
/// Content of the macOS `frus.noteComposer` utility window (UI audit C1).
///
/// Hosts the unchanged `ResearchNoteEditorView` so a researcher can read the
/// passage they are annotating while typing — the modal sheet this replaces
/// covered the document. Driven by the value-based window's `request`
/// (#363 — the scene is `WindowGroup(for: NoteComposerRequest.self)`; the
/// request-less restored-window placeholder lives in the scene, so this view
/// always has a concrete request). Each distinct request already gets its own
/// window (and thus its own fresh editor), so no `.id`-rekeying is needed; a
/// reused window keeps its in-progress draft for the same target.
///
/// No indexing-pipeline boot guard is needed: `ResearchNoteEditorView` tolerates
/// a nil pipeline (the FTS5 push is skipped).
///
/// Version history:
///   1.0 — Session 2026-07-04 (macOS UI audit C1): initial implementation
///   1.1 — #363: value-based window (`let request` in place of the
///         `pendingNoteComposer` `.task`/`.onChange` consume).
struct NoteComposerWindowView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    /// The request this value-based window presents (#363 — was an `AppState.pendingNoteComposer`
    /// hand-off; the window is now `WindowGroup(for: NoteComposerRequest.self)`, so the placeholder for
    /// a request-less restored window lives in the scene and this view always has a concrete request).
    let request: NoteComposerRequest

    var body: some View {
        ResearchNoteEditorView(
            documentId: request.documentId,
            volumeId: request.volumeId,
            activeProjectId: appState.activeProjectId,
            noteToEdit: fetchNote(request.noteId),
            linkedHighlightId: request.linkedHighlightId,
            indexingPipeline: appState.indexingPipeline
        )
    }

    /// Resolves an existing note id from the hand-off to its SwiftData model.
    /// Returns `nil` (create-new mode) when the id is absent or the note was
    /// deleted between hand-off and consumption.
    private func fetchNote(_ noteId: UUID?) -> ResearchNote? {
        guard let noteId else { return nil }
        let descriptor = FetchDescriptor<ResearchNote>(
            predicate: #Predicate { $0.id == noteId }
        )
        return try? modelContext.fetch(descriptor).first
    }
}
#endif

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
