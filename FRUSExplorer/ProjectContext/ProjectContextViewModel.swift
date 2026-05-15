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

// MARK: - ProjectContextViewModel

/// Manages the project list and orchestrates CRUD operations for the Project
/// management sheet.
///
/// ## Responsibilities
/// - Loads the `[Project]` list from SwiftData on demand.
/// - Manages sheet-presentation flags for create/edit and delete confirmation.
/// - Executes deletions: removes the record from SwiftData and from the local
///   `projects` array. Activity records (`ReadingHistoryEntry`, `ResearchNote`,
///   `Collection`) are intentionally NOT deleted — they retain the orphaned
///   `projectId` and remain accessible in global context.
///
/// Version history:
///   1.0 — Session 15: initial implementation
@Observable
@MainActor
final class ProjectContextViewModel {

    // MARK: - Project List

    var projects: [Project] = []

    // MARK: - Sheet State

    /// Whether the project editor sheet is presented.
    var showProjectEditor: Bool = false

    /// The project to edit, or `nil` when creating a new project.
    var projectToEdit: Project? = nil

    // MARK: - Delete Confirmation

    /// The project awaiting user confirmation before deletion.
    var projectPendingDeletion: Project? = nil

    /// Whether the delete confirmation dialog is presented.
    var showDeleteConfirmation: Bool = false

    // MARK: - Loading

    /// Loads all `Project` records from the SwiftData context into `projects`.
    func load(context: ModelContext) {
        projects = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        #if DEBUG
        print("[ProjectContext] Loaded \(projects.count) projects")
        #endif
    }

    // MARK: - Create / Edit

    func openCreate() {
        projectToEdit = nil
        showProjectEditor = true
    }

    func openEdit(_ project: Project) {
        projectToEdit = project
        showProjectEditor = true
    }

    // MARK: - Delete

    /// Stages `project` for deletion and shows the confirmation dialog.
    func requestDelete(_ project: Project) {
        projectPendingDeletion = project
        showDeleteConfirmation = true
    }

    /// Executes the confirmed deletion of `projectPendingDeletion`.
    ///
    /// Activity records that reference the deleted project are NOT removed —
    /// they retain the orphaned `projectId` per the spec (§15).
    func confirmDelete(context: ModelContext) {
        guard let project = projectPendingDeletion else { return }
        context.delete(project)
        projects.removeAll { $0.id == project.id }
        projectPendingDeletion = nil
        #if DEBUG
        print("[ProjectContext] Deleted project \(project.id) '\(project.name)'")
        #endif
    }
}
