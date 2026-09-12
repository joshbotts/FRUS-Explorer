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
/// Version history:
///   1.0 — Session 14: initial implementation
@Observable
@MainActor
final class ResearchNoteEditorViewModel {

    // MARK: - Editor State

    var bodyText: String = ""
    var projectIds: [UUID] = []
    var userTagIds: [UUID] = []
    var selectedSummaryIds: [UUID] = []

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
        self.noteToEdit = noteToEdit
        if let note = noteToEdit {
            bodyText = note.bodyText
            projectIds = note.projectIds
            userTagIds = note.userTagIds
            selectedSummaryIds = note.selectedSummaryIds
        } else if let pid = activeProjectId {
            projectIds = [pid]
        }
    }

    // MARK: - Loading

    /// Populates `availableUserTags`, `availableProjects`, and `availableSummaries`
    /// from the SwiftData context. Call once on view appear.
    func load(context: ModelContext) {
        richText = noteToEdit?.richText
        // **Sorted, which this was the one surface in the app not to do.** Both fetches were bare
        // descriptors, so the two lists came back in SwiftData's storage order — roughly creation
        // order, and stable only by accident. Every other tag or project list sorts by name. The
        // reader's own order is applied over this baseline by `ListOrderPreferences`; a permutation
        // needs something to permute.
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
    /// - Returns: The `id` of the saved note — used by callers to log a `noteSave` event.
    @discardableResult
    func save(context: ModelContext) -> UUID? {
        if let note = noteToEdit {
            note.bodyText = bodyText
            note.richText = richText
            note.projectIds = projectIds
            note.userTagIds = userTagIds
            note.selectedSummaryIds = selectedSummaryIds
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

    /// Deletes the note being edited from the SwiftData context. No-op for new notes.
    func delete(context: ModelContext) {
        guard let note = noteToEdit else { return }
        context.delete(note)
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
    /// Idempotent: calling twice for the same summary is a no-op.
    func promoteSummary(_ summary: GeneratedSummary) {
        guard !selectedSummaryIds.contains(summary.id) else { return }
        selectedSummaryIds.append(summary.id)
        // Through `replaceBody`, so the rich-text editor remounts and the reader actually SEES the
        // summary land. Appending to `bodyText` alone changed the model and left the screen as it
        // was — a button that appeared to do nothing.
        replaceBody(with: bodyText.isEmpty ? summary.responseText
                                           : bodyText + "\n\n" + summary.responseText)
        #if DEBUG
        print("[ResearchNoteEditor] Promoted summary \(summary.id)")
        #endif
    }

    /// Removes the summary ID from `selectedSummaryIds`. Does not modify `bodyText`.
    func demoteSummary(summaryId: UUID) {
        selectedSummaryIds.removeAll { $0 == summaryId }
    }
}
