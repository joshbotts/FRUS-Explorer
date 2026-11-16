// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Observation
import SwiftData

// MARK: - ResearchNoteEditorViewModel

/// Manages state for creating or editing a `ResearchNote`.
///
/// ## Creation vs Edit
/// Pass `noteToEdit: nil` to create a new note. The active project ID (if any) is
/// applied automatically as the first entry in `projectIds`. Pass a `ResearchNote`
/// to open it for editing — the note's existing fields are mirrored into the editor.
///
/// ## Summary Promotion
/// `promoteSummary(_:)` appends the summary's text to `bodyText` and records its
/// ID in `selectedSummaryIds`. `demoteSummary(summaryId:)` removes the ID without
/// modifying `bodyText`; the text remains as the user's own content.
///
/// ## Unsaved changes (L19, IPA-2)
/// The editor keeps nothing before Save, so ``opening`` records what it opened with and
/// ``hasChanges`` says whether leaving now would lose anything. The sheet's swipe and Discard ask
/// first while it is `true`, and a tap beside an iPad's sheet leaves the editor open. The record
/// lives here, never on the `ResearchNote` model: a stored property there would be a CloudKit
/// schema change, which 1.0 takes none of.
///
/// Version history:
///   1.0 — Session 14: initial implementation
///   1.1 — #1791: a save is written to every stored copy of the note, and a delete removes every
///          copy
///   1.2 — 2026-10-31: Insert into note adds a structured summary as its fields, a *Label: text*
///          paragraph each (``GeneratedSummary/plainReaderText(separator:)``), not its stored JSON
///   1.3 — L19 (#1919, IPA-2): ``opening`` and ``hasChanges``; the formatted body is read in `init`,
///          where it is recorded, not in `load(context:)`
@Observable
@MainActor
final class ResearchNoteEditorViewModel {

    // MARK: - Editor State

    var bodyText: String = ""
    var projectIds: [UUID] = []
    var userTagIds: [UUID] = []
    var selectedSummaryIds: [UUID] = []

    // MARK: - Unsaved changes (L19, IPA-2)

    /// What the editor holds that Save writes: the note's text, its formatted copy, and the ids it
    /// is filed and tagged under. The ids are sets, since a picker that takes a tag off and puts it
    /// back changes their order and nothing else.
    struct Snapshot: Equatable {
        /// The note's plain text.
        let bodyText: String
        /// The note's formatted text, or `nil` when it carries no formatting.
        let richText: Data?
        /// The projects the note is filed under.
        let projectIds: Set<UUID>
        /// The tags the note carries.
        let userTagIds: Set<UUID>
        /// The summaries inserted into the note.
        let selectedSummaryIds: Set<UUID>
    }

    /// What the editor opened with: the note being edited, or a new note's starting state (empty,
    /// filed under the active project). Recorded once, in `init`, and never written again, so an
    /// appearance of the editor after a picker closes cannot move it.
    let opening: Snapshot

    /// What the editor holds now.
    var current: Snapshot {
        Snapshot(bodyText: bodyText, richText: richText, projectIds: Set(projectIds),
                 userTagIds: Set(userTagIds), selectedSummaryIds: Set(selectedSummaryIds))
    }

    /// Whether leaving without saving would lose something the reader did here.
    ///
    /// The plain text, the projects, the tags and the inserted summaries are compared with
    /// ``opening``. Formatting is compared only while there is text to carry it: the rich editor
    /// serialises its whole storage on every edit, so typing a letter and deleting it leaves the
    /// plain text as it was and a fresh formatted copy, which is counted as a change, as it would be
    /// saved as one; an empty body has no formatting worth asking about.
    var hasChanges: Bool {
        let now = current
        guard now.bodyText == opening.bodyText,
              now.projectIds == opening.projectIds,
              now.userTagIds == opening.userTagIds,
              now.selectedSummaryIds == opening.selectedSummaryIds else { return true }
        return !now.bodyText.isEmpty && now.richText != opening.richText
    }

    // MARK: - New Tag Creation

    var newTagName: String = ""

    // MARK: - Available Data (loaded from SwiftData on appear)

    var availableUserTags: [UserTag] = []
    var availableSummaries: [GeneratedSummary] = []
    var availableProjects: [Project] = []

    // MARK: - Dependencies

    let documentId: String
    let volumeId: String
    let noteToEdit: ResearchNote?

    // MARK: - Init

    init(
        documentId: String,
        volumeId: String,
        activeProjectId: UUID?,
        noteToEdit: ResearchNote? = nil
    ) {
        self.documentId = documentId
        self.volumeId = volumeId
        // A note its editor has just deleted is built into an editor once more while the sheet that
        // showed it closes: the presenting view's content runs again, and a view's
        // `State(initialValue:)` builds its model each time. Measured on the iPad Pro 13-inch (M5)
        // under iOS 27.0, All Notes' sheet did so after Delete, on the code before L19 as on L19's,
        // and reading the deleted note's `projectIds` trapped in SwiftData. So a deleted or detached
        // note is read as none; the view keeps the model it already has, and this one is never shown
        // (L19, IPA-2).
        let note = noteToEdit.flatMap(Self.readable)
        self.noteToEdit = note
        let startingProjects = note?.projectIds ?? activeProjectId.map { [$0] } ?? []
        self.opening = Snapshot(bodyText: note?.bodyText ?? "",
                                richText: note?.richText,
                                projectIds: Set(startingProjects),
                                userTagIds: Set(note?.userTagIds ?? []),
                                selectedSummaryIds: Set(note?.selectedSummaryIds ?? []))
        if let note {
            bodyText = note.bodyText
            projectIds = note.projectIds
            userTagIds = note.userTagIds
            selectedSummaryIds = note.selectedSummaryIds
        } else if let pid = activeProjectId {
            projectIds = [pid]
        }
        // Here, beside the opening record, rather than in `load(context:)`, which runs at each
        // appearance: the record must agree with what the editor first shows, and a later read of
        // the stored copy must not replace formatting the reader has changed since.
        richText = note?.richText
    }

    /// `note`, or `nil` when it has been deleted or belongs to no context, when its stored values
    /// may no longer be read (L19, IPA-2: see `init`).
    ///
    /// - Parameter note: The note an editor was asked to open.
    /// - Returns: The note, if it can be read.
    static func readable(_ note: ResearchNote) -> ResearchNote? {
        note.isDeleted || note.modelContext == nil ? nil : note
    }

    // MARK: - Loading

    /// Populates `availableUserTags`, `availableProjects`, and `availableSummaries`
    /// from the SwiftData context. Call once on view appear.
    func load(context: ModelContext) {
        // **Sorted, which this was the one surface in the app not to do.** Both fetches were bare
        // descriptors, so the two lists came back in SwiftData's storage order — roughly creation
        // order, and stable only by accident. Every list that follows the reader's own order sorts
        // by name first, and `ListOrderPreferences` names those lists. The order is applied over
        // this baseline; a permutation needs something to permute.
        let tagsByName = (try? context.fetch(
            FetchDescriptor<UserTag>(sortBy: [SortDescriptor(\.name)]))) ?? []
        let projectsByName = (try? context.fetch(
            FetchDescriptor<Project>(sortBy: [SortDescriptor(\.name)]))) ?? []
        // Then the reader's own order over that baseline (#1275) — the names they are working with
        // now first, everything else still alphabetical behind them.
        availableUserTags = ListOrderPreferences.apply(
            tagsByName, order: ListOrderPreferences.order(for: .tags, in: context), id: \.id)
        availableProjects = ListOrderPreferences.apply(
            projectsByName, order: ListOrderPreferences.order(for: .projects, in: context),
            id: \.id)
        let docId = documentId
        let volId = volumeId
        let descriptor = FetchDescriptor<GeneratedSummary>(
            predicate: #Predicate { s in s.documentId == docId && s.volumeId == volId }
        )
        availableSummaries = (try? context.fetch(descriptor)) ?? []

        #if DEBUG
        print("[ResearchNoteEditor] Loaded: \(availableUserTags.count) tags, " +
              "\(availableProjects.count) projects, \(availableSummaries.count) summaries")
        #endif
    }

    // MARK: - Save / Delete

    /// Saves the editor state: updates the existing note or inserts a new one.
    ///
    /// An existing note's edit is written to every copy stored under its id
    /// (``ResearchNote/copies(of:in:)``, #1791), so the copies keep one text and the copy a list
    /// shows is the edited one whichever that is.
    ///
    /// - Returns: The `id` of the saved note — used by callers to log a `noteSave` event.
    @discardableResult
    func save(context: ModelContext) -> UUID? {
        if let note = noteToEdit {
            let otherCopies = ResearchNote.copies(of: note.id, in: context)
                .filter { $0.persistentModelID != note.persistentModelID }
            for copy in [note] + otherCopies {
                copy.bodyText = bodyText
                copy.richText = richText
                copy.projectIds = projectIds
                copy.userTagIds = userTagIds
                copy.selectedSummaryIds = selectedSummaryIds
            }
            #if DEBUG
            print("[ResearchNoteEditor] Saved note for \(volumeId)/\(documentId)")
            #endif
            return note.id
        } else {
            let note = ResearchNote(
                documentId: documentId,
                volumeId: volumeId,
                bodyText: bodyText,
                projectIds: projectIds,
                userTagIds: userTagIds,
                selectedSummaryIds: selectedSummaryIds
            )
            note.richText = richText
            context.insert(note)
            #if DEBUG
            print("[ResearchNoteEditor] Saved note for \(volumeId)/\(documentId)")
            #endif
            return note.id
        }
    }

    /// Deletes the note being edited from the SwiftData context, with every copy stored under its
    /// id (#1791), so it does not come back from one that remains. No-op for new notes.
    func delete(context: ModelContext) {
        guard let note = noteToEdit else { return }
        ResearchNote.deleteEveryCopy(of: note, in: context)
        #if DEBUG
        print("[ResearchNoteEditor] Deleted note \(note.id)")
        #endif
    }

    // MARK: - User Tag Management


    /// Creates a new `UserTag` from `newTagName`, inserts it, and applies it to the note.
    func createAndAddTag(context: ModelContext) {
        let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let tag = UserTag(name: trimmed)
        context.insert(tag)
        availableUserTags.append(tag)
        userTagIds.append(tag.id)
        newTagName = ""
        #if DEBUG
        print("[ResearchNoteEditor] Created tag '\(trimmed)'")
        #endif
    }

    // MARK: - Project Tag Management


    // MARK: - Rich text

    /// The formatted body, or `nil` when the note carries no formatting (#1275).
    ///
    /// `bodyText` remains the plain projection and stays authoritative for everything that reads a
    /// note without rendering it; this is only what the editor shows and what `save` stores.
    var richText: Data?

    /// Bumped whenever the body is replaced PROGRAMMATICALLY rather than by typing.
    ///
    /// The rich-text editor loads its content once, deliberately — its representables rebind only
    /// the change callback, so a row reused after a reorder does not lose what the reader typed.
    /// That is right for a list and wrong for an Insert button: appending a summary to `bodyText`
    /// would change the model and leave the screen alone, so the editor is keyed on this counter
    /// and remounts with the new content. Typing never bumps it, so a reader is never interrupted
    /// mid-word.
    private(set) var bodyRevision = 0

    /// Records plain typing, dropping any formatted copy it has just made stale.
    ///
    /// **The plain editor cannot simply write `bodyText`.** `save` stores both fields, and the rich
    /// editor prefers a decodable `richText` over its plain fallback whenever one exists — so a note
    /// edited with formatting OFF and reopened with it ON would show the reader their PREVIOUS
    /// prose. Worse, the first keystroke in that stale editor serialises the whole text storage back
    /// as `(rtf, plain)`, overwriting the plain text the reader actually wrote. Clearing here keeps
    /// the two copies from ever diverging; it costs nothing, because plain typing is exactly the act
    /// that invalidates the formatting.
    ///
    /// The revision is NOT bumped: the plain editor is not keyed on it, and bumping mid-keystroke
    /// would remount the rich editor the moment the reader turned formatting back on.
    func setPlainBody(_ text: String) {
        bodyText = text
        richText = nil
    }

    /// Replaces the body from code, so the editor picks the change up.
    func replaceBody(with text: String) {
        bodyText = text
        // The formatted copy cannot survive a wholesale text replacement, and keeping a stale one
        // would show the reader their old prose back. Plain text is the honest result here.
        richText = nil
        bodyRevision += 1
    }

    // MARK: - Summary Promotion

    /// Appends the summary's text to `bodyText` and records its ID in `selectedSummaryIds`.
    /// Idempotent: calling twice for the same summary is a no-op. A structured summary goes in as its
    /// fields, a *Label: text* paragraph each, and any other summary as its text.
    func promoteSummary(_ summary: GeneratedSummary) {
        guard !selectedSummaryIds.contains(summary.id) else { return }
        selectedSummaryIds.append(summary.id)
        // Through `replaceBody`, so the rich-text editor remounts and the reader actually SEES the
        // summary land. Appending to `bodyText` alone changed the model and left the screen as it
        // was — a button that appeared to do nothing.
        let text = summary.plainReaderText()
        replaceBody(with: bodyText.isEmpty ? text : bodyText + "\n\n" + text)
        #if DEBUG
        print("[ResearchNoteEditor] Promoted summary \(summary.id)")
        #endif
    }

    /// Removes the summary ID from `selectedSummaryIds`. Does not modify `bodyText`.
    func demoteSummary(summaryId: UUID) {
        selectedSummaryIds.removeAll { $0 == summaryId }
    }
}
