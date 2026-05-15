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
        availableUserTags = (try? context.fetch(FetchDescriptor<UserTag>())) ?? []
        availableProjects = (try? context.fetch(FetchDescriptor<Project>())) ?? []
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
    func save(context: ModelContext) {
        if let note = noteToEdit {
            note.bodyText = bodyText
            note.projectIds = projectIds
            note.userTagIds = userTagIds
            note.selectedSummaryIds = selectedSummaryIds
        } else {
            let note = ResearchNote(
                documentId: documentId,
                volumeId: volumeId,
                bodyText: bodyText,
                projectIds: projectIds,
                userTagIds: userTagIds,
                selectedSummaryIds: selectedSummaryIds
            )
            context.insert(note)
        }
        #if DEBUG
        print("[ResearchNoteEditor] Saved note for \(volumeId)/\(documentId)")
        #endif
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

    func toggleUserTag(_ tagId: UUID) {
        if userTagIds.contains(tagId) {
            userTagIds.removeAll { $0 == tagId }
        } else {
            userTagIds.append(tagId)
        }
    }

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

    func toggleProjectTag(_ projectId: UUID) {
        if projectIds.contains(projectId) {
            projectIds.removeAll { $0 == projectId }
        } else {
            projectIds.append(projectId)
        }
    }

    // MARK: - Summary Promotion

    /// Appends the summary's text to `bodyText` and records its ID in `selectedSummaryIds`.
    /// Idempotent: calling twice for the same summary is a no-op.
    func promoteSummary(_ summary: GeneratedSummary) {
        guard !selectedSummaryIds.contains(summary.id) else { return }
        selectedSummaryIds.append(summary.id)
        if bodyText.isEmpty {
            bodyText = summary.responseText
        } else {
            bodyText += "\n\n" + summary.responseText
        }
        #if DEBUG
        print("[ResearchNoteEditor] Promoted summary \(summary.id)")
        #endif
    }

    /// Removes the summary ID from `selectedSummaryIds`. Does not modify `bodyText`.
    func demoteSummary(summaryId: UUID) {
        selectedSummaryIds.removeAll { $0 == summaryId }
    }
}
