// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - ResearchNote

/// A user annotation attached to a specific FRUS document.
///
/// ## Project Tagging
/// `projectIds` carries the project tags applied to this note. A note is created
/// with the currently active project's ID (if any). Users can subsequently add or
/// remove project tags. A note is never deleted when a project tag is removed —
/// removal only hides the note from that project's lens.
///
/// ## Cross-Project Visibility
/// When a user views a document in a project that does not own this note, the note
/// is hidden by default but signaled via a disclosure indicator. The user can reveal
/// and optionally promote the note to the current project by adding its ID to
/// `projectIds`.
///
/// ## Selected Summaries
/// `selectedSummaryIds` lists `GeneratedSummary.id` values the user has promoted
/// to draft content in this note. The summaries are not embedded in the note —
/// they are referenced by ID so that note text remains the user's own words.
///
/// Version history:
///   1.0 — Session 04: initial implementation
@Model final class ResearchNote {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Document Reference

    /// The FRUS document this note is attached to.
    var documentId: String = "" {
        didSet { lastModified = .now }
    }

    /// The volume containing the document.
    var volumeId: String = "" {
        didSet { lastModified = .now }
    }

    // MARK: - Content

    /// The user's note text in plain text / Markdown.
    var bodyText: String = "" {
        didSet { lastModified = .now }
    }

    // MARK: - Tags and References

    /// IDs of `Project` records whose lens this note appears in.
    var projectIds: [UUID] = [] {
        didSet { lastModified = .now }
    }

    /// IDs of `UserTag` records the user has applied to this note.
    var userTagIds: [UUID] = [] {
        didSet { lastModified = .now }
    }

    /// IDs of `GeneratedSummary` records the user has promoted to draft content here.
    var selectedSummaryIds: [UUID] = [] {
        didSet { lastModified = .now }
    }

    // MARK: - Timestamps

    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var createdAt: Date?
    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var lastModified: Date?

    // MARK: - Initializer

    init(
        documentId: String,
        volumeId: String,
        bodyText: String = "",
        projectIds: [UUID] = [],
        userTagIds: [UUID] = [],
        selectedSummaryIds: [UUID] = []
    ) {
        self.id = UUID()
        self.documentId = documentId
        self.volumeId = volumeId
        self.bodyText = bodyText
        self.projectIds = projectIds
        self.userTagIds = userTagIds
        self.selectedSummaryIds = selectedSummaryIds
        let now = Date.now
        createdAt = now
        lastModified = now

        #if DEBUG
        print("[SwiftData] ResearchNote created: \(id) for \(volumeId)/\(documentId)")
        #endif
    }
}
