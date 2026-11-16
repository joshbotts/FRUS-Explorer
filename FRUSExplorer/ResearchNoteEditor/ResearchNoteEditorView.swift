// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import SwiftData
import OSLog

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
/// - Discard (cancellationAction): dismisses without saving — after "Discard Changes?" when the
///   editor holds changes (L19, IPA-2)
/// - Save (confirmationAction): persists and dismisses
/// - Delete (destructiveAction): deletes existing note and dismisses (edit mode only), after All
///   Notes' "Delete Note?" (L19, IPA-2)
///
/// ## Nothing typed is lost to a swipe (L19, IPA-2)
/// Nothing is saved before Save, so while the editor holds changes
/// (``ResearchNoteEditorViewModel/hasChanges``) the sheet's swipe asks "Discard Changes?" before
/// closing it, a tap beside an iPad's sheet leaves it open (``UnsavedNoteGuard``), and a Mac
/// composer window's close asks too.
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
///   1.2 — 2026-10-31: a structured summary in Generated Summaries shows as its labelled fields
///          (``GeneratedSummary/readerText``), not its stored JSON
///   1.3 — L19 (#1919, IPA-2): Discard and the sheet's swipe ask before losing changes, Delete asks
///          as All Notes does, and on the Mac Save and Delete dismiss a main-queue turn later
struct ResearchNoteEditorView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var vm: ResearchNoteEditorViewModel

    /// Whether "Discard Changes?" is up, from the Discard button (L19, IPA-2).
    @State private var confirmingDiscard = false
    /// Whether "Delete Note?" is up (L19, IPA-2).
    @State private var confirmingDelete = false
    /// Set as the editor leaves on purpose — Save, Delete, a confirmed Discard — so the guard on the
    /// sheet's dismissal stands down for the dismissal the reader chose (``close()``).
    @State private var isClosing = false

    /// Whether leaving now asks first: the editor holds changes, and is not already leaving.
    private var guardsChanges: Bool { vm.hasChanges && !isClosing }

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
                        confirmingDelete = true
                    }
                    .foregroundStyle(.red)
                    .modifier(DeleteNoteConfirmation(isPresented: $confirmingDelete, delete: deleteNote))
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
                    requestDiscard()
                }
                .keyboardShortcut(.cancelAction)
                .modifier(DiscardChangesConfirmation(isPresented: $confirmingDiscard,
                                                     isNewNote: vm.noteToEdit == nil,
                                                     discard: close))

                Spacer()

                Button(String(localized: "note.editor.toolbar.save", defaultValue: "Save")) {
                    // Wave R-2a / contract D2: the `.noteSave` research event is gone. It was
                    // redundant — `ResearchNote` carries `createdAt` and `lastModified` of its own
                    // — and nothing but the session log ever read it.
                    saveNote()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 520, minHeight: 440)
        .onAppear { vm.load(context: modelContext) }
        // L19 (IPA-2): closing the composer window with changes asks first, as the sheet's swipe does.
        .modifier(UnsavedNoteGuard(isActive: guardsChanges, isNewNote: vm.noteToEdit == nil,
                                   onRefusedDismissal: requestDiscard))
        .onChange(of: isClosing) { _, closing in dismissOnceStoodDown(closing) }
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
        // L19 (IPA-2): the sheet's swipe asks before losing changes; a tap beside an iPad's sheet is refused.
        .modifier(UnsavedNoteGuard(isActive: guardsChanges, isNewNote: vm.noteToEdit == nil,
                                   onRefusedDismissal: requestDiscard))
        .onChange(of: isClosing) { _, closing in dismissOnceStoodDown(closing) }
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

    /// Rebuilds the document's indexed note text after a save or a delete (#1280).
    ///
    /// Every caller must have saved first — `reindexNoteText` re-reads the document's notes, and the
    /// read is what includes the note just written and excludes the one just deleted.
    ///
    /// **Text only. The `userTagIds:` overload this once called is deleted (lane HYG).**
    /// `user_tag_ids` is a per-DOCUMENT column whose authoritative writer is
    /// `UserTagPickerSheet.saveAndDismiss`, which sends the document's whole assigned set. This
    /// editor knows only ONE note's tags, so passing them wrote a narrower set over a wider one —
    /// and a note with no tags of its own passed `nil`, which the column binder writes as SQL NULL
    /// rather than skipping, erasing the document's tags outright. Search opts into that column, so
    /// the damage showed up as search-by-tag missing documents until the next launch's replay put
    /// them back. The sibling defect in `CollectionEntryRows` was fixed the same way.
    private func pushNoteToFTS5() {
        guard let pipeline = indexingPipeline else { return }
        let vid = vm.volumeId
        let did = vm.documentId
        Task {
            await ResearchNote.reindexNoteText(volumeId: vid, documentId: did,
                                               in: modelContext, pipeline: pipeline)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(String(localized: "note.editor.toolbar.discard",
                          defaultValue: "Discard")) {
                requestDiscard()
            }
            // On the button, so that on an iPad the dialog hangs from it.
            .modifier(DiscardChangesConfirmation(isPresented: $confirmingDiscard,
                                                 isNewNote: vm.noteToEdit == nil,
                                                 discard: close))
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(String(localized: "note.editor.toolbar.save",
                          defaultValue: "Save")) {
                // Wave R-2a / contract D2: no `.noteSave` event — see the macOS toolbar above.
                saveNote()
            }
        }
        if vm.noteToEdit != nil {
            ToolbarItem(placement: .destructiveAction) {
                Button(
                    String(localized: "note.editor.toolbar.delete",
                           defaultValue: "Delete"),
                    role: .destructive
                ) {
                    confirmingDelete = true
                }
                .modifier(DeleteNoteConfirmation(isPresented: $confirmingDelete, delete: deleteNote))
            }
        }
    }

    // MARK: - Leaving (L19, IPA-2)

    /// Discard: leaves at once when there is nothing to lose, and asks "Discard Changes?" when
    /// there is.
    private func requestDiscard() {
        if guardsChanges {
            confirmingDiscard = true
        } else {
            dismiss()
        }
    }

    /// Saves the note, links it to the highlight it was written from, and leaves.
    ///
    /// The explicit context save puts the note in the store before the editor goes: the Research
    /// window's `@Query`, on the Mac another `ModelContext`, may otherwise not see it until
    /// SwiftData's own save, seconds later.
    private func saveNote() {
        if let noteId = vm.save(context: modelContext) {
            linkNoteToHighlight(noteId: noteId)
        }
        try? modelContext.save()
        pushNoteToFTS5()
        close()
    }

    /// Deletes the note, once "Delete Note?" is confirmed, and leaves.
    ///
    /// The save flushes the removal so a cross-context `@Query` (the Research window, Project Home's
    /// seed) sees it promptly, as Save's does. #1280: the index does not learn about a deletion by
    /// itself, so the push comes AFTER the save, and the re-read sees the note gone — and clears the
    /// column when it was the document's last.
    private func deleteNote() {
        vm.delete(context: modelContext)
        try? modelContext.save()
        pushNoteToFTS5()
        close()
    }

    /// Leaves the editor on purpose. It stands the guard down first, and ``dismissOnceStoodDown(_:)``
    /// dismisses after the update that draws it down: on the Mac the guard holds a programmatic
    /// dismissal too (`dismissalConfirmationDialog`), and the dismissal the reader has just chosen
    /// must go through.
    private func close() {
        isClosing = true
    }

    /// Dismisses once ``close()`` has stood the guard down. An `onChange` action runs after the
    /// update that changed its value, so a sheet's guard is already drawn down when it dismisses.
    ///
    /// On the Mac that is not enough. Dismissed from the `onChange`, the composer window refused the
    /// close and asked nothing, so Save and Delete left it open, Delete on the note it had just
    /// deleted (the Mac check copy, L19's walk), while Discard Changes, in the window's own dialog,
    /// closed it; most likely the window takes the guard's new `shouldPresent` only once that update
    /// has reached AppKit. Dismissed by a task on the main actor, on a later turn of the main queue,
    /// the window closes.
    private func dismissOnceStoodDown(_ closing: Bool) {
        guard closing else { return }
        #if os(macOS)
        Task { @MainActor in dismiss() }
        #else
        dismiss()
        #endif
    }
}

// MARK: - The note editor's dialogs (L19, IPA-2)

/// The words of the note editor's two dialogs: "Discard Changes?", and All Notes' "Delete Note?",
/// whose keys and words the editor's Delete shares so that both ask the same question.
///
/// Version history:
///   1.0 — L19 (#1919, IPA-2): initial implementation
enum NoteEditorDialogCopy {
    /// "Discard Changes?"
    static var discardTitle: String {
        String(localized: "note.editor.discard.title", defaultValue: "Discard Changes?")
    }
    /// The dialog's destructive button.
    static var discardAction: String {
        String(localized: "note.editor.discard.confirm", defaultValue: "Discard Changes")
    }
    /// The dialog's way back to the editor.
    static var keepEditing: String {
        String(localized: "note.editor.discard.keepEditing", defaultValue: "Keep Editing")
    }
    /// What would be lost: a new note's text, or an existing note's changes.
    ///
    /// - Parameter isNewNote: Whether the editor was opened to write a new note.
    static func discardMessage(isNewNote: Bool) -> String {
        isNewNote
            ? String(localized: "note.editor.discard.message.new",
                     defaultValue: "This note has not been saved.")
            : String(localized: "note.editor.discard.message.edit",
                     defaultValue: "Your changes to this note have not been saved.")
    }
    /// All Notes' title (`AllNotesScreen`).
    static var deleteTitle: String {
        String(localized: "settings.notes.delete.title", defaultValue: "Delete Note?")
    }
    /// All Notes' destructive button.
    static var deleteAction: String {
        String(localized: "settings.notes.delete.confirm", defaultValue: "Delete")
    }
    /// All Notes' cancel button.
    static var deleteCancel: String {
        String(localized: "settings.notes.delete.cancel", defaultValue: "Cancel")
    }
    /// All Notes' message.
    static var deleteMessage: String {
        String(localized: "settings.notes.delete.message",
               defaultValue: "This note will be permanently deleted.")
    }
}

/// "Discard Changes?" from the editor's Discard button (L19, IPA-2).
private struct DiscardChangesConfirmation: ViewModifier {
    /// Whether the dialog is up.
    @Binding var isPresented: Bool
    /// Whether the editor was opened to write a new note.
    let isNewNote: Bool
    /// Leaves without saving.
    let discard: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(NoteEditorDialogCopy.discardTitle, isPresented: $isPresented,
                                   titleVisibility: .visible) {
            Button(NoteEditorDialogCopy.discardAction, role: .destructive, action: discard)
            Button(NoteEditorDialogCopy.keepEditing, role: .cancel) {}
        } message: {
            Text(NoteEditorDialogCopy.discardMessage(isNewNote: isNewNote))
        }
    }
}

/// "Delete Note?" from the editor's Delete button, in All Notes' words (L19, IPA-2).
private struct DeleteNoteConfirmation: ViewModifier {
    /// Whether the dialog is up.
    @Binding var isPresented: Bool
    /// Deletes the note and leaves.
    let delete: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(NoteEditorDialogCopy.deleteTitle, isPresented: $isPresented,
                                   titleVisibility: .visible) {
            Button(NoteEditorDialogCopy.deleteAction, role: .destructive, action: delete)
            Button(NoteEditorDialogCopy.deleteCancel, role: .cancel) {}
        } message: {
            Text(NoteEditorDialogCopy.deleteMessage)
        }
    }
}

/// Asks "Discard Changes?" before the editor is closed by the system rather than by its buttons
/// (L19, IPA-2).
///
/// - **iPhone and iPad:** while there is something to lose the sheet refuses its swipe, and a tap
///   beside an iPad's sheet (`interactiveDismissDisabled`). A refused swipe raises the Discard
///   button's own dialog (``SheetDismissAttemptHook``). A refused tap beside the sheet raises
///   nothing and the editor stays: UIKit ignores a touch outside a sheet it holds modal and reports
///   no attempt (measured on the iPad Pro 13-inch (M5), iOS 27.0). SwiftUI's
///   `dismissalConfirmationDialog` is not the tool here: on iOS it guards a window's dismissal, not
///   a sheet's (Apple's documentation, read 2026-11-16).
/// - **Mac:** closing the composer window asks, through `dismissalConfirmationDialog`. Its
///   destructive button needs no action: every button but Cancel lets the dismissal proceed. It
///   holds a programmatic dismissal too, which is why Save and Delete stand it down and dismiss a
///   main-queue turn later (``ResearchNoteEditorView``'s `close()` and `dismissOnceStoodDown`).
private struct UnsavedNoteGuard: ViewModifier {
    /// Whether leaving now would lose changes.
    let isActive: Bool
    /// Whether the editor was opened to write a new note.
    let isNewNote: Bool
    /// What a refused swipe does: raises the Discard button's dialog.
    let onRefusedDismissal: () -> Void

    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .interactiveDismissDisabled(isActive)
            .background(SheetDismissAttemptHook(onAttempt: onRefusedDismissal))
        #else
        content
            .dismissalConfirmationDialog(Text(NoteEditorDialogCopy.discardTitle),
                                         shouldPresent: isActive) {
                Button(NoteEditorDialogCopy.discardAction, role: .destructive) {}
                Button(NoteEditorDialogCopy.keepEditing, role: .cancel) {}
            } message: {
                Text(NoteEditorDialogCopy.discardMessage(isNewNote: isNewNote))
            }
        #endif
    }
}

#if os(iOS)
/// Hears a sheet refuse its swipe while `interactiveDismissDisabled` holds it (L19, IPA-2), which
/// SwiftUI does not report.
///
/// UIKit does: it tells the presentation controller's delegate,
/// `presentationControllerDidAttemptToDismiss(_:)`. SwiftUI is that delegate, for its own reasons,
/// so this does not replace it: it puts ``SheetDismissAttemptRelay`` in its place, which passes every
/// call on to SwiftUI's and also calls `onAttempt` for this one. Placed in the sheet's content as a
/// background, from where its view's responder chain reaches the controller the sheet presents
/// (``HookController``).
private struct SheetDismissAttemptHook: UIViewControllerRepresentable {
    /// Called when the sheet has refused a dismissal.
    let onAttempt: () -> Void

    func makeUIViewController(context: Context) -> HookController {
        HookController(onAttempt: onAttempt)
    }

    func updateUIViewController(_ controller: HookController, context: Context) {
        controller.onAttempt = onAttempt
        controller.installRelay()
    }

    /// An empty view controller whose one job is to reach the sheet's presentation controller.
    final class HookController: UIViewController {
        /// Called when the sheet has refused a dismissal.
        var onAttempt: () -> Void
        /// The relay in the delegate's place, kept here because the delegate property is weak.
        private var relay: SheetDismissAttemptRelay?

        init(onAttempt: @escaping () -> Void) {
            self.onAttempt = onAttempt
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            installRelay()
        }

        /// Puts the relay in the sheet's delegate slot, or puts it back if something has replaced it
        /// since, wrapping whatever delegate is there now.
        func installRelay() {
            guard let presentation = presentedRoot()?.presentationController else { return }
            if let relay, presentation.delegate === relay { return }
            let relay = SheetDismissAttemptRelay(original: presentation.delegate) { [weak self] in
                self?.onAttempt()
            }
            #if DEBUG
            Self.log.debug("""
                [SheetDismissAttemptHook] relay in place of \
                \(String(describing: presentation.delegate.map { type(of: $0) }), privacy: .public)
                """)
            #endif
            self.relay = relay
            presentation.delegate = relay
        }

        /// The view controller the sheet presents: the first, walking up the responder chain from
        /// this one, that has no parent and a presenter. SwiftUI hosts this controller's view without
        /// making it a child of the sheet's controllers, so its own `presentationController` does not
        /// lead to the sheet's; its view's responder chain does.
        private func presentedRoot() -> UIViewController? {
            var responder: UIResponder? = self
            while let next = responder {
                if let controller = next as? UIViewController, controller !== self,
                   controller.parent == nil, controller.presentingViewController != nil {
                    return controller
                }
                responder = next.next
            }
            return nil
        }

        #if DEBUG
        /// The hook's debug log; XCUITest does not show the app's `print`.
        private static let log = Logger(subsystem: "bottsywattsy.FRUS-Explorer", category: "NoteEditorGuard")
        #endif
    }
}

/// Stands in a sheet's presentation-controller delegate slot for ``SheetDismissAttemptHook``:
/// tells the hook of a refused dismissal and passes every call, that one included, to the delegate
/// it replaced (SwiftUI's), which keeps the sheet's binding and its refusal working as before.
private final class SheetDismissAttemptRelay: NSObject, UIAdaptivePresentationControllerDelegate {
    /// The delegate this replaced. Weak, as UIKit holds a delegate, and read from the forwarding
    /// overrides, which the Objective-C runtime calls without regard to actors.
    nonisolated(unsafe) private weak var original: (any UIAdaptivePresentationControllerDelegate)?
    /// Called on a refused dismissal.
    private let onAttempt: @MainActor () -> Void

    init(original: (any UIAdaptivePresentationControllerDelegate)?,
         onAttempt: @escaping @MainActor () -> Void) {
        self.original = original
        self.onAttempt = onAttempt
        super.init()
    }

    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        original?.presentationControllerDidAttemptToDismiss?(presentationController)
        #if DEBUG
        Logger(subsystem: "bottsywattsy.FRUS-Explorer", category: "NoteEditorGuard")
            .debug("[SheetDismissAttemptRelay] the sheet refused a dismissal")
        #endif
        onAttempt()
    }

    nonisolated override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || (original?.responds(to: aSelector) ?? false)
    }

    nonisolated override func forwardingTarget(for aSelector: Selector!) -> Any? {
        (original?.responds(to: aSelector) ?? false) ? original : nil
    }
}
#endif

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
///   1.2 — #1791: a note stored as several copies opens the copy last modified
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

    /// Resolves an existing note id from the hand-off to its SwiftData model: the copy last
    /// modified, for a note stored as several (``ResearchNote/copies(of:in:)``, #1791).
    /// Returns `nil` (create-new mode) when the id is absent or the note was
    /// deleted between hand-off and consumption.
    private func fetchNote(_ noteId: UUID?) -> ResearchNote? {
        guard let noteId else { return nil }
        return ResearchNote.copies(of: noteId, in: modelContext).first
    }
}
#endif

// MARK: - SummaryPromotionRow

/// One of the document's summaries in Generated Summaries, as the reader shows it (a structured
/// summary's fields, each label bold), with its Insert into note or Remove from note button.
private struct SummaryPromotionRow: View {
    let summary: GeneratedSummary
    let isPromoted: Bool
    let onPromote: () -> Void
    let onDemote: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(summary.readerText)
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
