// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - Project

/// A Project is an activity lens, not a content container.
///
/// Working within a project context silently tags the user's actions — notes,
/// summaries, collections, and reading history — with that project. All content
/// is global; the active project filters what the user sees. Switching projects
/// is instantaneous: a state change in `AppState`, never a data migration.
///
/// ## Activity Tagging
/// The active project at the time of an action is recorded in the activity record
/// (`ReadingHistoryEntry.projectId`, `ResearchNote.projectIds`, etc.). The project
/// record itself does not own any content — it is referenced by activity records.
///
/// ## Project-Level Defaults
/// `defaultDateRangeStart`/`End`, `defaultSubjectTagIds`, and `defaultCountryTagIds`
/// pre-populate the Browser and Search views when this project is active. They are
/// suggestions, not filters: users can override them per-session.
///
/// ## `lastModified`
/// Updated automatically via `didSet` on every mutable property. Used by CloudKit
/// last-write-wins conflict resolution. Note: mutating elements of an array property
/// in-place (e.g. via `append`) does not trigger `didSet`; replace the array to
/// ensure the observer fires.
///
/// Version history:
///   1.0 — Session 04: initial implementation
@Model final class Project {

    // MARK: - Identity

    /// Stable UUID used by activity records to reference this project.
    /// Generated at initialization; never changes.
    var id: UUID = UUID()

    // MARK: - Content

    var name: String = "" {
        didSet { lastModified = .now }
    }

    var researchQuestion: String? {
        didSet { lastModified = .now }
    }

    // MARK: - Default Filters (pre-populate Browser/Search when project is active)

    var defaultDateRangeStart: Date? {
        didSet { lastModified = .now }
    }

    var defaultDateRangeEnd: Date? {
        didSet { lastModified = .now }
    }

    /// Subject tag IDs from the retired document-level subject taxonomy.
    ///
    /// Retained for schema/CloudKit stability only (Session 09): subject-tag search
    /// filtering is inert, `SearchViewModel.applyProjectDefaults` no longer reads this,
    /// and new projects are seeded with an empty list.
    var defaultSubjectTagIds: [String] = [] {
        didSet { lastModified = .now }
    }

    /// Country/place tag IDs to pre-filter when active.
    var defaultCountryTagIds: [String] = [] {
        didSet { lastModified = .now }
    }

    /// Per-project **Project Leads** axis weights (#377 Phase 3), stored as the `AxisWeights`
    /// raw string (`"axis:weight,…"`). `nil` = never tuned for this project, so leads use the
    /// researcher's global related-documents preference. Set once the researcher adjusts the
    /// project's lead weights.
    var leadAxisWeights: String? = nil {
        didSet { lastModified = .now }
    }

    // MARK: - Timestamps

    /// Set at creation; never mutated. Optional for CloudKit schema compatibility — always non-nil in practice.
    var createdAt: Date?

    /// Updated automatically on every mutation via `didSet` on each mutable property.
    /// Used by CloudKit conflict resolution (last-write-wins).
    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var lastModified: Date?

    // MARK: - Initializer

    init(
        name: String,
        researchQuestion: String? = nil,
        defaultDateRangeStart: Date? = nil,
        defaultDateRangeEnd: Date? = nil,
        defaultSubjectTagIds: [String] = [],
        defaultCountryTagIds: [String] = []
    ) {
        self.id = UUID()
        self.name = name
        self.researchQuestion = researchQuestion
        self.defaultDateRangeStart = defaultDateRangeStart
        self.defaultDateRangeEnd = defaultDateRangeEnd
        self.defaultSubjectTagIds = defaultSubjectTagIds
        self.defaultCountryTagIds = defaultCountryTagIds
        let now = Date.now
        createdAt = now
        lastModified = now

        #if DEBUG
        print("[SwiftData] Project created: \(id) '\(name)'")
        #endif
    }
}
