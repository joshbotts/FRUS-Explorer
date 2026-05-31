// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - DocumentTagAssignment

/// A direct tag-to-document association created when the user taps "Tag Document"
/// in the document view toolbar.
///
/// ## Why this model exists
/// `document_cache.user_tag_ids` (the SQLite FTS5 index) was the original storage
/// for direct tag assignments, but it is a local-only derived artifact that does not
/// sync via CloudKit. `DocumentTagAssignment` stores the same information in SwiftData
/// so it participates in the existing CloudKit private-database sync alongside
/// `UserTag` and `ResearchNote` records.
///
/// ## Relationship to `ResearchNote.userTagIds`
/// These are independent annotation types:
/// - `ResearchNote.userTagIds` — tags applied through the note editor (carries note text)
/// - `DocumentTagAssignment` — tags applied directly to a document (no note body)
///
/// Both are reflected in the Research window and FTS5 search. Neither depends on the other.
///
/// ## CloudKit compatibility
/// - All stored properties have default values
/// - No `@Relationship` declarations (avoids cascade issues)
/// - `tagId` is a plain `UUID`, not a `@Relationship` to `UserTag`, matching the same
///   pattern used by `ResearchNote.userTagIds: [UUID]`
///
/// ## FTS5 synchronisation
/// At app boot, `FRUSExplorerApp.bootApp()` pushes all `DocumentTagAssignment` records
/// for indexed volumes into `document_cache.user_tag_ids` so the FTS5 search index
/// reflects the CloudKit-synced state on every device.
///
/// Version history:
///   1.0 — Session 130: initial implementation, replacing `document_cache.user_tag_ids`
///          as the canonical store for direct document-level tag associations
@Model final class DocumentTagAssignment {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Document Reference

    /// The volume containing the tagged document.
    var volumeId: String = ""

    /// The document within the volume (e.g. `"d42"`).
    var documentId: String = ""

    // MARK: - Tag Reference

    /// The `UserTag.id` this assignment links to.
    ///
    /// Stored as a plain `UUID` (not a `@Relationship`) for CloudKit compatibility,
    /// matching the pattern used by `ResearchNote.userTagIds`.
    var tagId: UUID = UUID()

    // MARK: - Timestamps

    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var createdAt: Date? = nil

    // MARK: - Initialiser

    init(volumeId: String, documentId: String, tagId: UUID) {
        self.id         = UUID()
        self.volumeId   = volumeId
        self.documentId = documentId
        self.tagId      = tagId
        self.createdAt  = .now

        #if DEBUG
        print("[SwiftData] DocumentTagAssignment created: \(volumeId)/\(documentId) tag=\(tagId)")
        #endif
    }
}
